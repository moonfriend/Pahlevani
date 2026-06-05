/* ============================================================
   Pahlevani — Player (core experience)
   Auto-plays, live rep counter with bold feedback, auto-advance.
   ============================================================ */

function Player({ session, onBack, onEdit, repFx = 'bold', showMedia = true }) {
  const { EX } = window.PAHLEVANI;
  const items = session.items;
  const a = ACCENT[session.accent] || ACCENT.gold;
  const storeKey = 'pahlevani.pos.' + session.id;

  // ---- restore saved position ----
  const restored = React.useMemo(() => {
    try { return JSON.parse(localStorage.getItem(storeKey)) || {}; } catch (e) { return {}; }
  }, [storeKey]);

  const [index, setIndex] = React.useState(Math.min(restored.index || 0, items.length - 1));
  const [elapsed, setElapsed] = React.useState(restored.elapsed || 0);
  const [playing, setPlaying] = React.useState(true);
  const [finished, setFinished] = React.useState(false);
  const listRef = React.useRef(null);

  const item = items[index];
  const ex = EX[item.exerciseId];
  const isCustom = item.reps !== ex.reps;
  const perRep = ex.dur / ex.reps;
  const total = perRep * item.reps;
  const rep = Math.min(item.reps, Math.floor(elapsed / perRep) + 1);
  const repColor = isCustom ? 'var(--rep-custom)' : 'var(--rep-default)';
  const repBg = isCustom ? 'var(--rep-cus-bg)' : 'var(--rep-def-bg)';

  // ---- ticking ----
  const raf = React.useRef(0);
  const last = React.useRef(0);
  React.useEffect(() => {
    if (!playing) return;
    last.current = performance.now();
    const loop = (t) => {
      const dt = (t - last.current) / 1000;
      last.current = t;
      setElapsed((e) => {
        const ne = e + dt;
        if (ne >= total) {
          // advance
          if (index < items.length - 1) {
            setIndex((i) => i + 1);
            return 0;
          } else {
            setPlaying(false);
            setFinished(true);
            return total;
          }
        }
        return ne;
      });
      raf.current = requestAnimationFrame(loop);
    };
    raf.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf.current);
  }, [playing, total, index, items.length]);

  // ---- persist ----
  React.useEffect(() => {
    try { localStorage.setItem(storeKey, JSON.stringify({ index, elapsed })); } catch (e) {}
  }, [index, elapsed, storeKey]);

  // ---- keep active track in view ----
  React.useEffect(() => {
    const el = listRef.current && listRef.current.querySelector('[data-active="true"]');
    if (el && listRef.current) {
      const top = el.offsetTop - listRef.current.offsetTop - 60;
      listRef.current.scrollTo({ top, behavior: 'smooth' });
    }
  }, [index]);

  function go(i) {
    if (i < 0 || i >= items.length) return;
    setIndex(i); setElapsed(0); setFinished(false); setPlaying(true);
  }
  function toggle() {
    if (finished) { go(0); return; }
    setPlaying((p) => !p);
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--bg)' }}>
      {/* app bar */}
      <header style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 8px 6px 6px', flexShrink: 0 }}>
        <button onClick={onBack} style={{ width: 44, height: 44, borderRadius: 99, display: 'grid', placeItems: 'center', color: 'var(--on-surface)' }} title="Back">
          <Icon name="back" size={24} />
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: 'var(--on-faint)' }}>Play along</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--on-surface)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{session.title}</div>
        </div>
        <button onClick={() => onEdit(session)} style={{ width: 44, height: 44, borderRadius: 99, display: 'grid', placeItems: 'center', color: 'var(--on-muted)' }} title="Edit session">
          <Icon name="edit" size={21} />
        </button>
      </header>

      {/* exercise stage — tap to pause/resume */}
      <button onClick={toggle} style={{
        position: 'relative', margin: '2px 16px 0', borderRadius: 26, overflow: 'hidden',
        height: 232, flexShrink: 0, background: a.bg, color: a.fg, display: 'block', width: 'calc(100% - 32px)',
        border: '1px solid var(--border-soft)', textAlign: 'left',
      }}>
        <MediaStage ex={ex} accent={a} playing={playing} finished={finished} showMedia={showMedia} />

        {/* paused overlay */}
        {!playing && !finished && (
          <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', background: 'var(--scrim)', animation: 'scrimIn .2s' }}>
            <div style={{ width: 72, height: 72, borderRadius: 99, background: 'var(--surface)', display: 'grid', placeItems: 'center', boxShadow: 'var(--shadow-pop)', color: 'var(--primary)' }}>
              <Icon name="play" size={34} color="var(--primary)" style={{ marginLeft: 4 }} />
            </div>
          </div>
        )}
        {/* now playing pill */}
        {playing && (
          <div style={{ position: 'absolute', right: 14, bottom: 14, display: 'flex', alignItems: 'center', gap: 8, padding: '7px 12px 7px 10px', borderRadius: 99, background: 'var(--surface)', boxShadow: 'var(--shadow-card)' }}>
            <Equalizer color={a.fg} />
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--on-surface)' }}>Pause</span>
          </div>
        )}
      </button>

      {/* REP COUNTER — the moment */}
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 16, flexShrink: 0 }}>
        <div key={index + '-' + rep} style={{
          position: 'relative', display: 'inline-flex', alignItems: 'center', gap: 10,
          padding: '9px 20px 9px 16px', borderRadius: 99, background: repBg, color: repColor,
          animation: repFx === 'minimal' ? 'none' : (repFx === 'pulse' ? 'repPulse .4s var(--ease-emph)' : 'repPop .42s var(--ease-emph)'),
          boxShadow: '0 2px 10px -2px ' + (isCustom ? 'rgba(194,100,31,.4)' : 'rgba(47,125,82,.36)'),
        }}>
          {repFx === 'bold' && <span key={'flash' + rep} style={{ position: 'absolute', inset: 0, borderRadius: 99, background: 'currentColor', animation: 'repFlash .5s ease-out', pointerEvents: 'none' }} />}
          <span style={{ position: 'relative', width: 30, height: 30, borderRadius: 99, background: 'currentColor', display: 'grid', placeItems: 'center' }}>
            <span style={{ color: repBg, fontWeight: 800, fontSize: 15 }}>{rep}</span>
          </span>
          <span style={{ position: 'relative', fontWeight: 700, fontSize: 15, letterSpacing: 0.2 }}>
            Rep {rep} <span style={{ opacity: 0.6, fontWeight: 600 }}>of {item.reps}</span>
            {isCustom && <span style={{ fontSize: 11, fontWeight: 700, marginLeft: 6, opacity: 0.8 }}>· custom</span>}
          </span>
        </div>
      </div>

      {/* progress */}
      <div style={{ padding: '16px 24px 6px', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 7 }}>
          <span style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--on-surface)' }}>{ex.name}</span>
          <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--on-muted)', fontVariantNumeric: 'tabular-nums' }}>{clock(elapsed)} / {clock(total)}</span>
        </div>
        <div style={{ height: 6, borderRadius: 99, background: 'var(--surface-3)', overflow: 'hidden' }}>
          <div style={{ height: '100%', width: (elapsed / total * 100) + '%', background: 'var(--rep-default)', borderRadius: 99, transition: 'width .12s linear' }} />
        </div>
      </div>

      {/* track list */}
      <div ref={listRef} className="scroll" style={{ flex: 1, overflowY: 'auto', padding: '8px 12px 12px' }}>
        {items.map((tItem, i) => {
          const tex = EX[tItem.exerciseId];
          const tCustom = tItem.reps !== tex.reps;
          const active = i === index;
          return (
            <button key={i} data-active={active} onClick={() => go(i)} style={{
              width: '100%', display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left',
              padding: '10px 12px', borderRadius: 16, marginBottom: 2,
              background: active ? 'var(--surface-2)' : 'transparent',
            }}>
              <span style={{
                width: 28, height: 28, borderRadius: 9, flexShrink: 0, display: 'grid', placeItems: 'center',
                fontSize: 13, fontWeight: 700, fontVariantNumeric: 'tabular-nums',
                background: active ? a.fg : 'var(--surface-3)', color: active ? 'var(--on-primary)' : 'var(--on-muted)',
              }}>{i + 1}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14.5, fontWeight: active ? 700 : 600, color: active ? 'var(--on-surface)' : 'var(--on-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{tex.name}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                  {tex.media && tex.media.type !== 'none' && (
                    <MediaGlyph type={tex.media.type} size={12} color={tex.media.type === 'video' ? 'var(--secondary)' : 'var(--on-faint)'} />
                  )}
                  <span style={{ fontSize: 11.5, color: 'var(--on-faint)', fontWeight: 500 }}>{tex.gloss}</span>
                </div>
              </div>
              <span style={{
                fontSize: 11.5, fontWeight: 700, padding: '3px 9px', borderRadius: 99, flexShrink: 0,
                color: tCustom ? 'var(--rep-custom)' : 'var(--rep-default)',
                background: tCustom ? 'var(--rep-cus-bg)' : 'var(--rep-def-bg)',
              }}>{tItem.reps}×</span>
              {active ? (
                <span style={{ color: a.fg, display: 'grid', placeItems: 'center', width: 22 }}>
                  <Icon name={playing ? 'pause' : 'play'} size={18} color={a.fg} />
                </span>
              ) : <span style={{ width: 22 }} />}
            </button>
          );
        })}
        <div style={{ height: 4 }} />
      </div>

      {/* bottom transport */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28, padding: '10px 0 14px', flexShrink: 0, background: 'linear-gradient(0deg, var(--bg) 60%, transparent)' }}>
        <button onClick={() => go(index - 1)} disabled={index === 0} style={transportBtn(index === 0)} title="Previous">
          <Icon name="up" size={24} stroke={2.2} />
        </button>
        <button onClick={toggle} style={{
          width: 68, height: 68, borderRadius: 24, background: 'var(--primary)', color: 'var(--on-primary)',
          display: 'grid', placeItems: 'center', boxShadow: 'var(--shadow-pop)',
        }} title={playing ? 'Pause' : 'Play'}>
          <Icon name={finished ? 'refresh' : (playing ? 'pause' : 'play')} size={30} color="var(--on-primary)" style={{ marginLeft: (!playing && !finished) ? 3 : 0 }} />
        </button>
        <button onClick={() => go(index + 1)} disabled={index === items.length - 1} style={transportBtn(index === items.length - 1)} title="Next">
          <Icon name="down" size={24} stroke={2.2} />
        </button>
      </div>

      {finished && <CompleteSheet session={session} onReplay={() => go(0)} onBack={onBack} />}
    </div>
  );
}

function transportBtn(disabled) {
  return {
    width: 52, height: 52, borderRadius: 99, background: 'var(--surface-2)',
    color: disabled ? 'var(--on-faint)' : 'var(--on-surface)',
    display: 'grid', placeItems: 'center', opacity: disabled ? 0.5 : 1,
    border: '1px solid var(--border-soft)',
  };
}

function Equalizer({ color }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2.5, height: 14 }}>
      {[0, 1, 2].map((i) => (
        <span key={i} style={{
          width: 3, borderRadius: 2, background: color,
          animation: `eq 0.7s ease-in-out ${i * 0.18}s infinite alternate`,
          height: 6 + i * 3,
        }} />
      ))}
      <style>{`@keyframes eq { from { height: 4px } to { height: 14px } }`}</style>
    </div>
  );
}

function CompleteSheet({ session, onReplay, onBack }) {
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 20, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div onClick={onBack} style={{ position: 'absolute', inset: 0, background: 'var(--scrim)', animation: 'scrimIn .25s' }} />
      <div style={{ position: 'relative', background: 'var(--surface)', borderRadius: '28px 28px 0 0', padding: '12px 24px 28px', animation: 'sheetUp .35s var(--ease-emph)', overflow: 'hidden' }}>
        <div style={{ width: 36, height: 4, borderRadius: 9, background: 'var(--border)', margin: '0 auto 18px' }} />
        <div style={{ position: 'relative', height: 84, borderRadius: 20, background: 'var(--primary-bg)', color: 'var(--primary)', overflow: 'hidden', display: 'grid', placeItems: 'center', marginBottom: 18 }}>
          <PersianPattern tile={84} stroke={1.3} opacity={0.5} />
          <span className="fa" style={{ position: 'relative', fontSize: 28, fontWeight: 700, color: 'var(--primary)' }}>خسته نباشی</span>
        </div>
        <h2 style={{ margin: '0 0 4px', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 24, color: 'var(--on-surface)', textAlign: 'center' }}>Session complete</h2>
        <p style={{ margin: '0 0 22px', fontSize: 14, color: 'var(--on-muted)', textAlign: 'center', lineHeight: 1.5 }}>
          You moved through all {session.items.length} exercises of <b style={{ color: 'var(--on-surface)' }}>{session.title}</b>. Khaste nabâshi — may you never tire.
        </p>
        <div style={{ display: 'flex', gap: 12 }}>
          <button onClick={onBack} style={{ flex: 1, height: 52, borderRadius: 16, background: 'var(--surface-2)', color: 'var(--on-surface)', fontWeight: 700, fontSize: 15, border: '1px solid var(--border-soft)' }}>Done</button>
          <button onClick={onReplay} style={{ flex: 1, height: 52, borderRadius: 16, background: 'var(--primary)', color: 'var(--on-primary)', fontWeight: 700, fontSize: 15, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <Icon name="refresh" size={20} color="var(--on-primary)" /> Again
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { Player });
