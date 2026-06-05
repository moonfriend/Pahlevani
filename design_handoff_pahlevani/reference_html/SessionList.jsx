/* ============================================================
   Pahlevani — Session List (home)
   ============================================================ */

const ACCENT = {
  gold:      { fg: 'var(--primary)',   bg: 'var(--primary-bg)' },
  terracotta:{ fg: 'var(--secondary)', bg: 'var(--secondary-bg)' },
  teal:      { fg: 'var(--teal)',      bg: 'var(--teal-bg)' },
};

// download status glyph (right side of card)
function DownloadStatus({ state, progress = 0, accent, onClick }) {
  const a = ACCENT[accent] || ACCENT.gold;
  const stop = (e) => { e.stopPropagation(); onClick && onClick(); };
  if (state === 'downloaded') {
    return (
      <button onClick={stop} title="Downloaded · tap to remove" style={{
        width: 34, height: 34, borderRadius: 99, background: 'var(--rep-def-bg)',
        display: 'grid', placeItems: 'center', color: 'var(--rep-default)',
      }}>
        <Icon name="check" size={19} stroke={2.4} />
      </button>
    );
  }
  if (state === 'downloading') {
    const R = 14, C = 2 * Math.PI * R;
    return (
      <button onClick={stop} title={`Downloading ${Math.round(progress * 100)}%`} style={{
        width: 34, height: 34, borderRadius: 99, position: 'relative',
        display: 'grid', placeItems: 'center', color: a.fg, background: a.bg,
      }}>
        <svg width="34" height="34" viewBox="0 0 34 34" style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
          <circle cx="17" cy="17" r={R} fill="none" stroke="currentColor" strokeWidth="2.4" opacity="0.25" />
          <circle cx="17" cy="17" r={R} fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"
                  strokeDasharray={C} strokeDashoffset={C * (1 - progress)} style={{ transition: 'stroke-dashoffset .3s linear' }} />
        </svg>
        <span style={{ width: 8, height: 8, borderRadius: 1.5, background: 'currentColor' }} />
      </button>
    );
  }
  return (
    <button onClick={stop} title="Download for offline" style={{
      width: 34, height: 34, borderRadius: 99, background: 'var(--surface-3)',
      display: 'grid', placeItems: 'center', color: 'var(--on-muted)',
    }}>
      <Icon name="download" size={19} stroke={2} />
    </button>
  );
}

function MetaRow({ session }) {
  const { fmtDur, sessionSeconds } = window.PAHLEVANI;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: 'var(--on-muted)', fontSize: 12.5, fontWeight: 600 }}>
        <Icon name="list" size={15} stroke={2.1} /> {session.items.length} tracks
      </span>
      <span style={{ width: 3, height: 3, borderRadius: 9, background: 'var(--on-faint)' }} />
      <span style={{ color: 'var(--on-muted)', fontSize: 12.5, fontWeight: 600 }}>{fmtDur(sessionSeconds(session))}</span>
      <div style={{ flex: 1 }} />
      <Difficulty level={session.difficulty} />
    </div>
  );
}

function YoursChip() {
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, letterSpacing: 0.3, color: 'var(--teal)',
      background: 'var(--teal-bg)', padding: '3px 9px', borderRadius: 99,
      display: 'inline-flex', alignItems: 'center', gap: 4,
    }}>Yours</span>
  );
}

// ---- card: BANNER layout ----
function BannerCard({ session, dl, onOpen, onMenu, onDownload }) {
  const a = ACCENT[session.accent] || ACCENT.gold;
  return (
    <article onClick={() => onOpen(session)} style={{
      background: 'var(--surface)', borderRadius: 24, overflow: 'hidden',
      border: '1px solid var(--border-soft)', boxShadow: 'var(--shadow-card)', cursor: 'pointer',
    }}>
      <div style={{ position: 'relative', height: 104, background: a.bg, color: a.fg, overflow: 'hidden' }}>
        <PersianPattern tile={120} stroke={1.3} opacity={0.5} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(105deg, var(--surface) -10%, transparent 70%)', opacity: 0.55 }} />
        <div style={{ position: 'absolute', left: 18, bottom: 12, right: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 2 }}>
            {session.isUserCreated && <YoursChip />}
          </div>
          <h3 style={{ margin: 0, fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 22, color: 'var(--on-surface)', lineHeight: 1.1 }}>
            {session.title}
          </h3>
        </div>
        <span className="fa" style={{ position: 'absolute', top: 12, right: 16, fontSize: 19, fontWeight: 600, color: a.fg, opacity: 0.92 }}>{session.fa}</span>
      </div>
      <div style={{ padding: '14px 18px 16px' }}>
        <p style={{
          margin: '0 0 12px', fontSize: 13.5, lineHeight: 1.5, color: 'var(--on-muted)',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{session.description}</p>
        <MetaRow session={session} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 14 }}>
          <DownloadStatus state={dl.state} progress={dl.progress} accent={session.accent} onClick={() => onDownload(session)} />
          <div style={{ flex: 1 }} />
          <button onClick={(e) => { e.stopPropagation(); onMenu(session); }} style={{
            width: 34, height: 34, borderRadius: 99, display: 'grid', placeItems: 'center', color: 'var(--on-muted)',
          }} title="More">
            <Icon name="more" size={20} />
          </button>
        </div>
      </div>
    </article>
  );
}

// ---- card: COMPACT layout (thumbnail left) ----
function CompactCard({ session, dl, onOpen, onMenu, onDownload }) {
  const a = ACCENT[session.accent] || ACCENT.gold;
  return (
    <article onClick={() => onOpen(session)} style={{
      background: 'var(--surface)', borderRadius: 22, padding: 12, display: 'flex', gap: 14,
      border: '1px solid var(--border-soft)', boxShadow: 'var(--shadow-card)', cursor: 'pointer',
    }}>
      <div style={{ width: 92, alignSelf: 'stretch', minHeight: 92, borderRadius: 16, position: 'relative', overflow: 'hidden', background: a.bg, color: a.fg, flexShrink: 0, display: 'grid', placeItems: 'center' }}>
        <PersianPattern tile={86} stroke={1.2} opacity={0.62} />
        <span className="fa" style={{ position: 'relative', fontSize: 22, fontWeight: 700, color: a.fg }}>{session.fa.split(' ')[0]}</span>
      </div>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <h3 style={{ margin: 0, fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 17.5, color: 'var(--on-surface)', lineHeight: 1.15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{session.title}</h3>
              {session.isUserCreated && <YoursChip />}
            </div>
          </div>
          <button onClick={(e) => { e.stopPropagation(); onMenu(session); }} style={{ width: 28, height: 28, borderRadius: 99, display: 'grid', placeItems: 'center', color: 'var(--on-muted)', marginRight: -4, marginTop: -2 }} title="More">
            <Icon name="more" size={19} />
          </button>
        </div>
        <p style={{
          margin: '4px 0 0', fontSize: 12.5, lineHeight: 1.45, color: 'var(--on-muted)',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{session.description}</p>
        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 10 }}>
          <MetaRow session={session} />
          <DownloadStatus state={dl.state} progress={dl.progress} accent={session.accent} onClick={() => onDownload(session)} />
        </div>
      </div>
    </article>
  );
}

function SessionList({ sessions, downloads, layout, refreshing, onRefresh, onOpen, onMenu, onDownload, onNew }) {
  const Card = layout === 'compact' ? CompactCard : BannerCard;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* large title app bar */}
      <header style={{ padding: '12px 20px 8px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <h1 style={{ margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 30, letterSpacing: -0.3, color: 'var(--on-surface)' }}>Pahlevani</h1>
              <span className="fa" style={{ fontSize: 20, fontWeight: 600, color: 'var(--primary)' }}>پهلوانی</span>
            </div>
            <p style={{ margin: '2px 0 0', fontSize: 13, color: 'var(--on-muted)', fontWeight: 500 }}>Varzesh-e Bastani · house of strength</p>
          </div>
          <button onClick={onRefresh} title="Pull to refresh" style={{
            width: 40, height: 40, borderRadius: 99, display: 'grid', placeItems: 'center',
            color: 'var(--on-muted)', background: 'var(--surface-2)',
          }}>
            <Icon name="refresh" size={21} stroke={2} style={{ animation: refreshing ? 'spin360 .8s linear infinite' : 'none' }} />
          </button>
        </div>
      </header>

      {refreshing && (
        <div style={{ textAlign: 'center', fontSize: 12, color: 'var(--on-muted)', padding: '0 0 6px', fontWeight: 600 }}>
          Syncing from Supabase…
        </div>
      )}

      <div className="scroll" style={{ flex: 1, overflowY: 'auto', padding: '6px 16px 96px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ fontSize: 12.5, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: 'var(--on-faint)', padding: '4px 4px 0' }}>
          {sessions.length} sessions
        </div>
        {sessions.map((s, i) => (
          <div key={s.id}>
            <Card session={s} dl={downloads[s.id]} onOpen={onOpen} onMenu={onMenu} onDownload={onDownload} />
          </div>
        ))}
      </div>

      {/* FAB */}
      <button onClick={onNew} style={{
        position: 'absolute', right: 18, bottom: 16, height: 56, borderRadius: 18, padding: '0 20px 0 16px',
        background: 'var(--primary)', color: 'var(--on-primary)', display: 'flex', alignItems: 'center', gap: 8,
        boxShadow: 'var(--shadow-pop)', fontWeight: 700, fontSize: 15,
      }} title="New session">
        <Icon name="add" size={22} stroke={2.4} /> New
      </button>
    </div>
  );
}

Object.assign(window, { SessionList, ACCENT, DownloadStatus });
