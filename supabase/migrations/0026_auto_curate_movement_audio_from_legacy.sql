-- Bulk-migrates every legacy exercise recording into movement_audio_track,
-- reusing its existing audio_url (no re-upload) — so the app no longer needs
-- exercise.author/audio_url/etc. once this has run and been verified.
--
-- Needs no fuzzy matching: movement.type_id has already been hand-assigned
-- for every real movement (via admin.py's "Assign movements to a type"),
-- including cases a name-matcher would get wrong (e.g. movement "Paye
-- Zabdari" -> type "22_paye_zarbdari"). This just reads that and pairs it
-- with the exercise's own author (matched case-insensitively to an existing
-- musician).
--
-- Multiple exercises collapsing onto the same (type, musician) pair (e.g.
-- Mile Aram's three exercises, all Sirvan) is expected and handled by the
-- existing unique constraint + ON CONFLICT DO NOTHING — first one in wins,
-- same as the manually-inserted 0024 test row it'll happily no-op against.
--
-- Exercises whose movement has no type_id yet, or whose author doesn't
-- match any musician, are silently skipped (the join/where excludes them) —
-- nothing errors, they just aren't migrated until curated.

insert into public.movement_audio_track
    (movement_type_id, musician_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
select
    mv.type_id,
    mu.id,
    ex.audio_url,
    coalesce(ex.repetitions, 1),
    ex.duration_seconds,
    ex.audio_anchor_ms
from public.exercise ex
join public.movement mv on mv.id = ex.movement_id
join public.musician mu on lower(mu.name) = lower(ex.author)
where ex.audio_url is not null
  and mv.type_id is not null
on conflict (movement_type_id, musician_id) do nothing;
