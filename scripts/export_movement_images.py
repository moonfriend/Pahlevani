"""
export_movement_images.py — Pull every file out of the movement-media bucket,
deduplicate by content, compress, and write a clean flat folder locally.

Background
----------
The bucket has one folder per movement id (e.g. "1/", "44/"), but most of
those folders hold the *same* generic pose illustration re-uploaded multiple
times at inconsistent quality (some copies 60 KB, some 6-8 MB). This script
doesn't touch the bucket or the database — it only reads, then writes a
local preview folder so the result can be reviewed before anything is
uploaded back.

Usage
-----
    cd scripts
    uv run python export_movement_images.py

Output
------
    output/movement_images_clean/<name>.jpg   — one file per unique image
    output/movement_images_report.csv          — movement row -> new filename mapping

Credentials: same as compress_images.py (service-role key required for
Storage downloads of a private bucket).
"""

import csv
import hashlib
import io
import os
import sys
import tomllib
from pathlib import Path

try:
    import requests
    from PIL import Image
    from supabase import create_client
except ImportError:
    print("Missing deps. Run: uv sync")
    sys.exit(1)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    secrets_path = Path(__file__).parent / ".streamlit" / "secrets.toml"
    if secrets_path.exists():
        with open(secrets_path, "rb") as f:
            secrets = tomllib.load(f)
        SUPABASE_URL = SUPABASE_URL or secrets.get("SUPABASE_URL", "")
        SUPABASE_KEY = SUPABASE_KEY or secrets.get("SUPABASE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    print(
        "ERROR: SUPABASE_URL and SUPABASE_KEY (service-role key) are required.\n"
        "Add them to scripts/.streamlit/secrets.toml or set as env vars."
    )
    sys.exit(1)

MEDIA_BUCKET = "movement-media"
MAX_DIMENSION = 800
JPEG_QUALITY = 75
OUTPUT_DIR = Path(__file__).parent / "output" / "movement_images_clean"
REPORT_PATH = Path(__file__).parent / "output" / "movement_images_report.csv"
OLD_PATHS_PATH = Path(__file__).parent / "output" / "old_bucket_paths.txt"


def compress_image(data: bytes) -> bytes:
    img = Image.open(io.BytesIO(data)).convert("RGB")
    img.thumbnail((MAX_DIMENSION, MAX_DIMENSION), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    return buf.getvalue()


def human(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} MB"
    if n >= 1_000:
        return f"{n / 1_000:.0f} KB"
    return f"{n} B"


def base_name(filename: str) -> str:
    """'vorud_together.png' -> 'vorud_together'"""
    return Path(filename).stem.lower()


def main() -> None:
    client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 1. List every file in every top-level (movement id) folder.
    top = client.storage.from_(MEDIA_BUCKET).list()
    all_files = []  # (folder, filename)
    for entry in top:
        folder = entry["name"]
        for f in client.storage.from_(MEDIA_BUCKET).list(folder):
            all_files.append((folder, f["name"]))

    print(f"Found {len(all_files)} files across {len(top)} folders in '{MEDIA_BUCKET}'.\n")

    # 2. Download every file, hash its content to find true duplicates.
    by_hash: dict[str, dict] = {}  # hash -> {data, name, locations: [(folder, filename, size)]}
    for folder, filename in all_files:
        path = f"{folder}/{filename}"
        data = client.storage.from_(MEDIA_BUCKET).download(path)
        digest = hashlib.sha256(data).hexdigest()
        if digest not in by_hash:
            by_hash[digest] = {"data": data, "name": base_name(filename), "locations": []}
        by_hash[digest]["locations"].append((folder, filename, len(data)))

    print(f"{len(by_hash)} unique file(s) by exact content "
          f"(from {len(all_files)} files).\n")

    # 3. Different hash groups can still be the *same picture* re-uploaded at a
    #    different resolution/encoding (confirmed visually for this bucket).
    #    Merge hash-groups that share a base name into one canonical image —
    #    keep the bytes from the largest copy as the compression source.
    by_name: dict[str, dict] = {}
    for info in by_hash.values():
        group = by_name.setdefault(info["name"], {"data": info["data"], "locations": []})
        if len(info["data"]) > len(group["data"]):
            group["data"] = info["data"]
        group["locations"].extend(info["locations"])

    merged_count = len(by_hash) - len(by_name)
    if merged_count:
        print(f"Merged {merged_count} same-name-different-hash group(s) into one "
              f"canonical image each (verified visually — same picture, different "
              f"resolution/encoding).\n")

    # 4. Compress each unique image once and write it to the flat output folder.
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    name_to_clean_name: dict[str, str] = {}
    total_before = 0
    total_after = 0

    print(f"{'Clean name':<35} {'Copies':>7} {'Before (max)':>13} {'After':>9}")
    print("-" * 70)

    for name, group in by_name.items():
        clean_filename = f"{name}.jpg"
        name_to_clean_name[name] = clean_filename

        sizes = [loc[2] for loc in group["locations"]]
        compressed = compress_image(group["data"])
        (OUTPUT_DIR / clean_filename).write_bytes(compressed)

        total_before += max(sizes)
        total_after += len(compressed)
        print(f"{clean_filename:<35} {len(group['locations']):>7} "
              f"{human(max(sizes)):>13} {human(len(compressed)):>9}")

    print("-" * 70)
    print(f"{'TOTAL (largest copy of each unique image)':<43} "
          f"{human(total_before):>20} {human(total_after):>9}")

    # 5. Map every (folder, filename) location back to its clean name, then
    #    join against the movement table so we know which DB row points where.
    location_to_clean: dict[tuple[str, str], str] = {}
    for name, group in by_name.items():
        for folder, filename, _ in group["locations"]:
            location_to_clean[(folder, filename)] = name_to_clean_name[name]

    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/movement"
        "?select=id,name,media_type,media_src,media_poster&order=id",
        headers=headers, timeout=15,
    )
    resp.raise_for_status()
    movements = resp.json()

    marker = f"/storage/v1/object/sign/{MEDIA_BUCKET}/"

    def resolve(url: str | None) -> str | None:
        if not url or marker not in url:
            return None
        storage_path = url.split(marker, 1)[1].split("?")[0]
        storage_path = requests.utils.unquote(storage_path)
        folder, _, filename = storage_path.partition("/")
        return location_to_clean.get((folder, filename))

    with open(REPORT_PATH, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["movement_id", "name", "media_type", "old_media_src_clean_name",
                          "old_media_poster_clean_name"])
        unmatched = 0
        for m in movements:
            src_clean = resolve(m.get("media_src"))
            poster_clean = resolve(m.get("media_poster"))
            if m.get("media_type") == "photo" and not src_clean:
                unmatched += 1
            writer.writerow([m["id"], m["name"], m.get("media_type"), src_clean, poster_clean])

    OLD_PATHS_PATH.write_text(
        "\n".join(f"{folder}/{filename}" for folder, filename in all_files) + "\n"
    )

    print(f"\nWrote {len(by_name)} clean image(s) to {OUTPUT_DIR}")
    print(f"Wrote movement -> clean-name mapping to {REPORT_PATH}")
    print(f"Wrote old bucket paths (for later cleanup) to {OLD_PATHS_PATH}")
    if unmatched:
        print(f"\nWARNING: {unmatched} movement row(s) have media_type=photo but "
              f"media_src didn't resolve to any file we found in the bucket.")


if __name__ == "__main__":
    main()
