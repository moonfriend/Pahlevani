# Switching media fully to Cloudflare R2 — checklist

Goal: serve all audio + images from the R2 bucket (`morshed-sounds`, zero egress)
instead of Supabase Storage, and point the DB at the new URLs.

Bucket: **morshed-sounds** · Account: `52a61783f2d01cd161e65ac58f130716`
R2 S3 endpoint: `https://52a61783f2d01cd161e65ac58f130716.r2.cloudflarestorage.com`

---

## 0. Before you start
- [ ] Decide the **public base URL** for the bucket. Either:
  - the R2.dev dev URL (`https://<hash>.r2.dev/…`), or
  - a **custom domain** attached to the bucket (recommended for prod, e.g. `media.pahlevani.app`).
- [ ] Have the Supabase **service-role** key and R2 API token (Object Read+List, +Write for upload) ready.
- [ ] Work on a branch; do the DB URL swap against the **local Docker / dev** Supabase first, verify, then repeat on prod.

## 1. Upload the files to R2
- [ ] Get the current file list from the DB: `exercise.url` (audio) and `movement.media_src` (images).
- [ ] **Pre-resize images before upload.** The app currently relies on Supabase's
      `/storage/v1/render/image/...` transform (`lib/core/utils/image_transform.dart`) to shrink
      images to 500×500 q80. **R2 has no transform endpoint**, so whatever you upload is what ships.
      Use `scripts/compress_images.py` to produce 500×500 versions, then upload those. (Alternative:
      put Cloudflare Images or a resize Worker in front of R2 — larger change, defer.)
- [ ] Upload audio as-is, images pre-resized. Keep a **stable path scheme** (e.g. mirror the Supabase
      storage path after the bucket segment) so URL rewriting in step 3 is mechanical.

## 2. Verify completeness (nothing missed)
- [ ] Run the checker (already written):
  ```bash
  cd scripts
  export SUPABASE_URL=https://<project-ref>.supabase.co
  export SUPABASE_KEY=<service-role-key>
  export R2_ACCESS_KEY_ID=<token-id>
  export R2_SECRET_ACCESS_KEY=<token-secret>
  uv run python check_r2_completeness.py     # exit 0 = all present
  ```
- [ ] Resolve any "missing" rows before touching URLs.

## 3. Point the DB at R2 URLs
- [ ] Back up the current values first (so a rollback is a single UPDATE):
  ```sql
  -- keep the old URLs somewhere retrievable
  alter table exercise add column if not exists url_supabase text;
  update exercise set url_supabase = url where url_supabase is null;
  alter table movement add column if not exists media_src_supabase text;
  update movement set media_src_supabase = media_src where media_src_supabase is null;
  ```
- [ ] Rewrite to R2 public URLs (adjust the marker/base to your scheme):
  ```sql
  update exercise
    set url = replace(url, 'https://<ref>.supabase.co/storage/v1/object/public/<bucket>/',
                           'https://<r2-base>/')
    where url like '%supabase.co/storage/%';
  update movement
    set media_src = replace(media_src, 'https://<ref>.supabase.co/storage/v1/object/public/<bucket>/',
                                       'https://<r2-base>/')
    where media_src like '%supabase.co/storage/%';
  ```
- [ ] Do this on **dev first**, launch the app against dev, confirm audio + images load.

## 4. CORS (required for web audio/images)
- [ ] Set the R2 bucket CORS policy so the browser can fetch + seek audio:
  ```json
  [{ "AllowedOrigins": ["*"],
     "AllowedMethods": ["GET", "HEAD"],
     "AllowedHeaders": ["Range"],
     "ExposeHeaders": ["Content-Range", "Content-Length", "Accept-Ranges"],
     "MaxAgeSeconds": 3600 }]
  ```
  (Tighten `AllowedOrigins` to your web domain later.) `Range`/`Content-Range` are what let the
  `<audio>` element seek; without them web seeking breaks.
- [ ] Set sensible cache headers on the objects (`Cache-Control: public, max-age=31536000, immutable`)
      since filenames are content-stable.

## 5. App-side verification
- [ ] Mobile: audio streams + caches, images load. (URL-hash cache filenames self-invalidate when a
      URL changes, so stale local media re-downloads once — expected.)
- [ ] Linux desktop: same.
- [ ] Web (`flutter run -d chrome`): audio plays and **seeks**; images load (confirms CORS is right).
- [ ] Confirm the image-transform no-op is acceptable: R2 URLs won't match the Supabase transform
      marker, so `supabaseImageTransformUrl()` returns them unchanged — which is why step 1 pre-resizing
      matters. If images look too large/heavy, that's the cause.

## 6. Cut over prod + clean up
- [ ] Repeat steps 1–5 against **prod** Supabase.
- [ ] Monitor a day for missing-media/crashlytics reports.
- [ ] Once stable, drop the `*_supabase` backup columns and (optionally) remove files from Supabase Storage.

## Notes / gotchas
- **No server-side image resize on R2** — biggest behavioural difference; handle by pre-resizing (step 1).
- **Signed URLs** are not needed for a public bucket; keep everything public + immutable.
- Keep `check_r2_completeness.py` env vars out of shell history (use a `.env` / `direnv`).
