/* ============================================================
   Pahlevani — MediaStage
   Renders the exercise demonstration in the Player stage.
   Priority by exercise.media.type:
     video → looping muted clip, play/pause synced to session
     photo → cover still (subtle ken-burns while playing)
     slot  → user-fillable drop target (prototype: drop a real photo)
     none  → Persian-pattern fallback
   showMedia=false forces the pattern treatment everywhere (Tweak).
   Title / rep overlays sit above a scrim so they stay legible.
   ============================================================ */

function MediaStage({ ex, accent, playing, finished, showMedia }) {
  const a = accent;
  const media = (showMedia && ex.media) ? ex.media : { type: 'none' };
  const videoRef = React.useRef(null);
  const hasReal = media.type === 'video' && media.src;

  // sync the demo clip to the session transport
  React.useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    if (playing && !finished) { v.play && v.play().catch(() => {}); }
    else { v.pause && v.pause(); }
  }, [playing, finished, ex.id]);

  const overImagery = media.type === 'photo' || media.type === 'video' || media.type === 'slot';

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      {/* ---- layer 1: the media ---- */}
      {media.type === 'video' && (
        hasReal ? (
          <video ref={videoRef} src={media.src} poster={media.poster || undefined}
                 muted loop playsInline preload="metadata"
                 style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          // production wires a real clip; prototype shows a labelled motion placeholder
          <PlaceholderMedia a={a} kind="video" playing={playing} />
        )
      )}
      {media.type === 'photo' && (
        media.src ? (
          <img src={media.src} alt={ex.name} style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover',
            animation: playing ? 'kenburns 14s ease-in-out infinite alternate' : 'none',
          }} />
        ) : (
          <PlaceholderMedia a={a} kind="photo" playing={playing} />
        )
      )}
      {media.type === 'slot' && (
        <image-slot class="move-slot" id={'move-' + ex.id} shape="rect"
                    placeholder={'Drop a photo of ' + ex.name}></image-slot>
      )}
      {media.type === 'none' && (
        <div style={{ position: 'absolute', inset: 0, background: a.bg, color: a.fg }}>
          <PersianPattern tile={132} stroke={1.5} opacity={playing ? 0.55 : 0.32} style={{ transition: 'opacity .4s' }} />
        </div>
      )}

      {/* ---- layer 2: legibility scrim ---- */}
      {overImagery ? (
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(8,5,2,0.45) 0%, transparent 32%, transparent 52%, rgba(8,5,2,0.72) 100%)' }} />
      ) : (
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(120% 90% at 50% 0%, transparent 30%, var(--bg) 140%)', opacity: 0.5 }} />
      )}

      {/* ---- layer 3: title ---- */}
      <div style={{ position: 'absolute', left: 22, top: 18, right: 22 }}>
        <span className="fa" style={{ fontSize: 40, fontWeight: 700, lineHeight: 1.1, display: 'block', color: overImagery ? '#fff' : a.fg, textShadow: overImagery ? '0 2px 14px rgba(0,0,0,0.5)' : 'none' }}>{ex.fa}</span>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 23, marginTop: 4, color: overImagery ? '#fff' : 'var(--on-surface)', textShadow: overImagery ? '0 2px 12px rgba(0,0,0,0.6)' : 'none' }}>{ex.name}</div>
        <div style={{ fontSize: 13, fontWeight: 500, marginTop: 1, color: overImagery ? 'rgba(255,255,255,0.82)' : 'var(--on-muted)', textShadow: overImagery ? '0 1px 8px rgba(0,0,0,0.6)' : 'none' }}>{ex.gloss}</div>
      </div>

      {/* ---- media-type badge (top-right) ---- */}
      {media.type !== 'none' && (
        <div style={{
          position: 'absolute', top: 16, right: 16, display: 'flex', alignItems: 'center', gap: 5,
          padding: '5px 10px', borderRadius: 99, fontSize: 11, fontWeight: 700, letterSpacing: 0.3,
          background: overImagery ? 'rgba(0,0,0,0.42)' : 'var(--surface)', color: overImagery ? '#fff' : a.fg,
          backdropFilter: 'blur(6px)',
        }}>
          <MediaGlyph type={media.type} size={13} />
          {media.type === 'video' ? 'Demo' : media.type === 'slot' ? 'Add photo' : 'Photo'}
        </div>
      )}
    </div>
  );
}

// labelled striped placeholder for unshipped assets (per the brief, imagery is TBD)
function PlaceholderMedia({ a, kind, playing }) {
  const id = React.useMemo(() => 'st' + Math.random().toString(36).slice(2, 7), []);
  return (
    <div style={{ position: 'absolute', inset: 0, background: a.bg, color: a.fg, overflow: 'hidden' }}>
      <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.5 }} aria-hidden="true">
        <defs>
          <pattern id={id} width="14" height="14" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
            <rect width="7" height="14" fill="currentColor" opacity="0.18" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill={`url(#${id})`} />
      </svg>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 16, display: 'flex', justifyContent: 'center' }}>
        <span style={{
          fontFamily: 'ui-monospace, monospace', fontSize: 11, fontWeight: 600, letterSpacing: 0.3,
          color: '#fff', background: 'rgba(0,0,0,0.4)', padding: '5px 11px', borderRadius: 8, backdropFilter: 'blur(4px)',
          display: 'inline-flex', alignItems: 'center', gap: 6,
        }}>
          {kind === 'video'
            ? <><span style={{ width: 7, height: 7, borderRadius: 99, background: playing ? '#ff5a4d' : '#fff', boxShadow: playing ? '0 0 8px #ff5a4d' : 'none' }} /> {playing ? 'demo clip · playing' : 'demo clip'}</>
            : 'move photo'}
        </span>
      </div>
    </div>
  );
}

function MediaGlyph({ type, size = 14, color = 'currentColor' }) {
  if (type === 'video') {
    return (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round"><rect x="3" y="6" width="13" height="12" rx="2.5"/><path d="M16 10l5-3v10l-5-3z" fill={color} stroke="none"/></svg>);
  }
  if (type === 'slot') {
    return (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 5v14M5 12h14"/></svg>);
  }
  // photo
  return (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="8.5" cy="10" r="1.6" fill={color} stroke="none"/><path d="M5 17l4.5-4 3 2.5L16 12l3 3"/></svg>);
}

Object.assign(window, { MediaStage, MediaGlyph });
