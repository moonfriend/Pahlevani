"""
check_media_integrity.py
════════════════════════
Verifies that public.media_asset (migration 0041) holds the correct size for
every media file the database references — the sizes the app shows before a
session is downloaded. Run it whenever you like; run it with --fix once after
applying 0041 to backfill sizes for everything uploaded before then.

For every URL in media_assets.REFERENCE_COLUMNS it checks, against the object
actually stored on R2 (HTTP HEAD → Content-Length):

  • the file exists and can be sized          (else: UNREACHABLE)
  • it has a media_asset row                  (else: MISSING ROW)
  • the recorded size equals the real size    (else: SIZE MISMATCH)

Rows nothing references any more are listed as ORPHAN (informational).

  --fix   writes the real size for missing/mismatched rows and stamps every
          verified row's checked_at. Unreachable files can't be fixed here.

Exit code: 0 when clean (after --fix, if given), 1 otherwise — usable in a
scheduled job.

Usage (service-role key needed for --fix; reads work with it too):
  PAHLEVANI_ENV=staging bash scripts/with_admin_creds.sh \\
      uv run python scripts/check_media_integrity.py [--fix]
"""

from __future__ import annotations

import argparse
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import TextIO

from media_assets import (
    MediaAsset,
    build_integrity_report,
    collect_referenced_urls,
    load_recorded_sizes,
    mark_verified,
    remote_size,
)


def run(db, http, *, fix: bool, now: datetime, out: TextIO,
        workers: int = 8) -> int:
    """Checks (and with [fix], repairs) media_asset; returns the exit code."""
    referenced = collect_referenced_urls(db)
    recorded = load_recorded_sizes(db)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        sizes = dict(zip(referenced,
                         pool.map(lambda u: remote_size(u, http), referenced)))
    report = build_integrity_report(
        referenced=referenced, recorded=recorded, actual=sizes)

    print(f"Referenced media files: {len(referenced)}", file=out)
    print(f"  OK:             {len(report.ok)}", file=out)
    for url, was, real in report.size_mismatches:
        print(f"  SIZE MISMATCH:  {url}  recorded={was}  actual={real}", file=out)
    for url, real in report.missing_rows:
        print(f"  MISSING ROW:    {url}  actual={real}", file=out)
    for url in report.unreachable:
        print(f"  UNREACHABLE:    {url}", file=out)
    for url in report.orphan_rows:
        print(f"  orphan row:     {url}", file=out)

    if not fix:
        return 0 if report.is_clean else 1

    fixes = report.fixes()
    verified = fixes + [MediaAsset(u, recorded[u]) for u in report.ok]
    mark_verified(db, verified, now=now)
    print(f"Fixed {len(fixes)} row(s); stamped {len(verified)} as verified.",
          file=out)
    return 0 if not report.unreachable else 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Verify (and with --fix, repair) media_asset file sizes "
                    "against the objects stored on R2.")
    parser.add_argument("--fix", action="store_true",
                        help="write real sizes for missing/wrong rows")
    args = parser.parse_args(argv)

    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set — run via "
              "scripts/with_admin_creds.sh (see this file's docstring).",
              file=sys.stderr)
        return 2

    import requests
    from supabase import create_client

    with requests.Session() as http:
        return run(create_client(url, key), http, fix=args.fix,
                   now=datetime.now(timezone.utc), out=sys.stdout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
