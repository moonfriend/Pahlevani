"""
Image size checker — fetches movement images from Supabase and compares
original URL vs the 500×500/quality-80 transform URL used by the app.

Run:
    cd scripts
    uv run python check_image_sizes.py [--env staging]

Credentials: reads SUPABASE_URL/SUPABASE_ANON_KEY straight from
env/supabase.<env>.env at the repo root (JSON, same file Flutter builds use).
The anon key is sufficient — movement table and storage bucket are public.
"""

import json
import os
import sys

try:
    import requests
except ImportError:
    print("Missing deps. Run: uv add requests")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------
_env_name = "staging" if "--env" in sys.argv and "staging" in sys.argv else "prod"
_env_path = os.path.join(
    os.path.dirname(__file__), "..", "env", f"supabase.{_env_name}.env"
)

with open(_env_path) as f:
    _creds = json.load(f)

SUPABASE_URL = _creds["SUPABASE_URL"]
SUPABASE_KEY = _creds["SUPABASE_ANON_KEY"]


def transform_url(url: str, width=500, height=500, quality=80) -> str:
    if not url:
        return url
    if "/storage/v1/object/public/" in url:
        transformed = url.replace("/storage/v1/object/public/", "/storage/v1/render/image/public/", 1)
    elif "/storage/v1/object/sign/" in url:
        transformed = url.replace("/storage/v1/object/sign/", "/storage/v1/render/image/sign/", 1)
    else:
        return url
    sep = "&" if "?" in transformed else "?"
    return f"{transformed}{sep}width={width}&height={height}&resize=contain&quality={quality}"


def fetch_size(url: str, session: requests.Session) -> tuple[int | None, bool]:
    """Returns (Content-Length in bytes, is_error). 4xx/5xx responses return (size, True)."""
    try:
        r = session.get(url, stream=True, timeout=15)
        if r.status_code >= 400:
            return None, True
        content = b""
        for chunk in r.iter_content(chunk_size=65536):
            content += chunk
        return len(content), False
    except Exception as e:
        print(f"  Error fetching {url[:80]}…: {e}")
        return None, True


def human(n: int | None) -> str:
    if n is None:
        return "?"
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} MB"
    if n >= 1_000:
        return f"{n / 1_000:.1f} KB"
    return f"{n} B"


def main():
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    }

    # Fetch all movement rows that have a photo src
    url = f"{SUPABASE_URL}/rest/v1/movement?select=id,name,media_type,media_src&media_type=eq.photo&media_src=not.is.null"
    resp = requests.get(url, headers=headers, timeout=15)
    resp.raise_for_status()
    rows = resp.json()

    if not rows:
        print("No photo movements found in the database.")
        return

    print(f"Found {len(rows)} movement(s) with photo media.\n")
    print(f"{'#':<4} {'Name':<35} {'Original':>10}  {'Transformed':>12}  {'Savings':>8}")
    print("-" * 75)

    session = requests.Session()
    total_orig = 0
    total_transformed = 0
    missing_transform = 0

    for i, row in enumerate(rows, 1):
        name = (row.get("name") or "")[:34]
        src = row.get("media_src") or ""

        if not src:
            print(f"{i:<4} {name:<35} {'(no src)':>10}")
            continue

        orig_size, orig_err = fetch_size(src, session)
        t_url = transform_url(src)

        if t_url == src:
            # Not a Supabase storage URL (or signed URL) — transform not applicable
            t_size, t_err = None, False
            missing_transform += 1
        else:
            t_size, t_err = fetch_size(t_url, session)

        transform_note = " [403-transforms disabled]" if t_err else ""
        savings = ""
        if orig_size and t_size and not t_err:
            pct = (1 - t_size / orig_size) * 100
            savings = f"{pct:+.0f}%"
            total_orig += orig_size
            total_transformed += t_size
        elif orig_size:
            total_orig += orig_size

        t_display = "N/A (paid)" if t_err else human(t_size)
        print(
            f"{i:<4} {name:<35} {human(orig_size):>10}  {t_display:>18}  {savings:>8}{transform_note}"
        )

    print("-" * 85)
    print(f"{'TOTAL original size':<55} {human(total_orig):>10}")
    if total_transformed > 0:
        overall_pct = (1 - total_transformed / total_orig) * 100
        print(f"{'TOTAL transformed size':<55} {human(total_transformed):>10}  ({overall_pct:+.0f}%)")
    if missing_transform:
        print(
            f"\nNote: {missing_transform} image(s) are in a private bucket (signed URLs).\n"
            "  → Supabase image transforms require the Pro plan for signed URLs.\n"
            "  → Fix: re-upload images pre-compressed to ~150–300 KB JPEG (use Pillow in admin.py),\n"
            "         OR move images to a public bucket and upgrade to Supabase Pro."
        )


if __name__ == "__main__":
    main()
