/* ============================================================
   Pahlevani — shared UI helpers
   PersianPattern (geometric tilework fill), Icon, Stars, etc.
   Exports to window for the other babel scripts.
   ============================================================ */

// ---------- Geometric star tessellation (khatam tilework) ----------
function starPath(cx, cy, R, r) {
  const pts = [];
  for (let i = 0; i < 16; i++) {
    const rad = i % 2 === 0 ? R : r;
    const a = (i * Math.PI) / 8 - Math.PI / 2;
    pts.push([cx + rad * Math.cos(a), cy + rad * Math.sin(a)]);
  }
  return 'M' + pts.map((p) => p[0].toFixed(2) + ',' + p[1].toFixed(2)).join('L') + 'Z';
}
function diamond(cx, cy, d) {
  return `M${cx},${cy - d}L${cx + d},${cy}L${cx},${cy + d}L${cx - d},${cy}Z`;
}

/* A repeating Persian star-and-cross lattice rendered as line-art.
   color + opacity controlled by parent; fills its positioned parent. */
function PersianPattern({ tile = 132, stroke = 1.4, opacity = 1, fill = false, style }) {
  const id = React.useMemo(() => 'pp' + Math.random().toString(36).slice(2, 8), []);
  const T = tile, R = T * 0.345, r = R * 0.54, d = T * 0.125;
  const paths = [
    starPath(0, 0, R, r),
    starPath(T, 0, R, r),
    starPath(0, T, R, r),
    starPath(T, T, R, r),
    starPath(T / 2, T / 2, R, r),
    diamond(T / 2, 0, d),
    diamond(0, T / 2, d),
    diamond(T, T / 2, d),
    diamond(T / 2, T, d),
    diamond(T / 2, T / 2 - R - d * 0.2, d * 0.6),
  ].join(' ');
  return (
    <svg
      aria-hidden="true"
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity, pointerEvents: 'none', ...style }}
    >
      <defs>
        <pattern id={id} width={T} height={T} patternUnits="userSpaceOnUse">
          <path d={paths} fill={fill ? 'currentColor' : 'none'} stroke="currentColor"
                strokeWidth={stroke} strokeLinejoin="round" fillOpacity={fill ? 0.16 : 0} />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}

// ---------- Icons (Material-style line glyphs) ----------
const ICONS = {
  back:    'M15.5 4.5 8 12l7.5 7.5',
  more:    'M12 5.2a1.6 1.6 0 1 0 0 3.2 1.6 1.6 0 0 0 0-3.2zm0 5.2a1.6 1.6 0 1 0 0 3.2 1.6 1.6 0 0 0 0-3.2zm0 5.2a1.6 1.6 0 1 0 0 3.2 1.6 1.6 0 0 0 0-3.2z',
  play:    'M8 5.5v13l11-6.5z',
  pause:   'M8 5.5h3.2v13H8zM12.8 5.5H16v13h-3.2z',
  up:      'M12 5.5 5.5 12M12 5.5 18.5 12M12 5.5V19',
  down:    'M12 18.5 5.5 12M12 18.5 18.5 12M12 18.5V5',
  check:   'M5 12.5 10 17.5 19 7',
  close:   'M6 6 18 18M18 6 6 18',
  edit:    'M4 16.5 15.5 5l3.5 3.5L7.5 20H4zM13.5 7 17 10.5',
  trash:   'M5 7h14M9.5 7V5h5v2M7 7l1 13h8l1-13',
  drag:    'M9 6h0M9 12h0M9 18h0M15 6h0M15 12h0M15 18h0',
  add:     'M12 5v14M5 12h14',
  refresh: 'M19 12a7 7 0 1 1-2.05-4.95M19 4v4h-4',
  download:'M12 4v10M7.5 10 12 14.5 16.5 10M5 19h14',
  star:    'M12 3.5l2.6 5.55 6.0.7-4.5 4.1 1.2 6-5.3-3-5.3 3 1.2-6-4.5-4.1 6-.7z',
  list:    'M4 7h16M4 12h16M4 17h10',
  bolt:    'M13 3 5 13h6l-1 8 8-10h-6z',
  wind:    'M3 9h11a2.5 2.5 0 1 0-2.5-2.5M3 14h14a2.5 2.5 0 1 1-2.5 2.5M3 12h7',
};
function Icon({ name, size = 24, stroke = 2, fill = false, color = 'currentColor', style }) {
  const filled = name === 'play' || name === 'pause' || (fill && name === 'star');
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: 'block', flexShrink: 0, ...style }}>
      <path d={ICONS[name]} fill={filled ? color : 'none'} stroke={filled ? 'none' : color}
            strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// ---------- Difficulty pips ----------
function Difficulty({ level, size = 7, color = 'var(--secondary)' }) {
  return (
    <div style={{ display: 'flex', gap: 4, alignItems: 'center' }} title={`Difficulty ${level} of 5`}>
      {[1, 2, 3, 4, 5].map((i) => (
        <span key={i} style={{
          width: size, height: size, borderRadius: 2, transform: 'rotate(45deg)',
          background: i <= level ? color : 'var(--border)',
          opacity: i <= level ? 1 : 0.8,
        }} />
      ))}
    </div>
  );
}

// ---------- mm:ss ----------
function clock(sec) {
  sec = Math.max(0, Math.round(sec));
  const m = Math.floor(sec / 60), s = sec % 60;
  return m + ':' + String(s).padStart(2, '0');
}

const TYPE_ICON = {
  breath: 'wind', warmup: 'wind', strength: 'bolt', club: 'bolt',
  spin: 'refresh', footwork: 'bolt',
};

Object.assign(window, { PersianPattern, Icon, Difficulty, clock, TYPE_ICON });
