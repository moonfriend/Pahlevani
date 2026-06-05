/* ============================================================
   Pahlevani — App root
   Screen routing, overflow menu, download lifecycle, tweaks.
   ============================================================ */

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "dark": true,
  "cardLayout": "banner",
  "repFx": "bold",
  "showMedia": true
}/*EDITMODE-END*/;

function initDownloads() {
  const m = {};
  window.PAHLEVANI.SESSIONS.forEach((s) => {
    m[s.id] = { state: s.download || 'none', progress: s.downloadProgress || 0 };
  });
  return m;
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const theme = t.dark ? 'dark' : 'light';

  // fit the 392x850 phone into any viewport
  const [scale, setScale] = React.useState(1);
  React.useEffect(() => {
    const fit = () => setScale(Math.min(1, (window.innerHeight - 36) / 850, (window.innerWidth - 24) / 392));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);

  const [sessions, setSessions] = React.useState(() => window.PAHLEVANI.SESSIONS.map((s) => ({ ...s })));
  const [downloads, setDownloads] = React.useState(initDownloads);
  const [screen, setScreen] = React.useState('list');         // list | player | edit
  const [active, setActive] = React.useState(null);
  const [menuFor, setMenuFor] = React.useState(null);          // overflow sheet
  const [confirmDel, setConfirmDel] = React.useState(null);
  const [refreshing, setRefreshing] = React.useState(false);
  const [toast, setToast] = React.useState(null);
  const dlTimers = React.useRef({});

  function flash(msg) { setToast(msg); clearTimeout(flash._t); flash._t = setTimeout(() => setToast(null), 2200); }

  // ---- download lifecycle ----
  function toggleDownload(session) {
    const cur = downloads[session.id] || { state: 'none', progress: 0 };
    if (cur.state === 'downloaded') {
      setDownloads((d) => ({ ...d, [session.id]: { state: 'none', progress: 0 } }));
      flash('Removed download · ' + session.title);
      return;
    }
    if (cur.state === 'downloading') return;
    // start
    flash('Downloading ' + session.title + '…');
    setDownloads((d) => ({ ...d, [session.id]: { state: 'downloading', progress: cur.progress || 0.04 } }));
    clearInterval(dlTimers.current[session.id]);
    dlTimers.current[session.id] = setInterval(() => {
      setDownloads((d) => {
        const p = (d[session.id].progress || 0) + 0.045 + Math.random() * 0.05;
        if (p >= 1) {
          clearInterval(dlTimers.current[session.id]);
          setTimeout(() => flash('Downloaded · ' + session.title), 0);
          return { ...d, [session.id]: { state: 'downloaded', progress: 1 } };
        }
        return { ...d, [session.id]: { state: 'downloading', progress: p } };
      });
    }, 260);
  }

  // simulate downloading sessions progressing on first mount
  React.useEffect(() => {
    Object.entries(downloads).forEach(([id, dl]) => {
      if (dl.state === 'downloading') {
        const s = sessions.find((x) => x.id === id);
        if (s) startProgress(id, s);
      }
    });
    return () => Object.values(dlTimers.current).forEach(clearInterval);
    // eslint-disable-next-line
  }, []);
  function startProgress(id, s) {
    clearInterval(dlTimers.current[id]);
    dlTimers.current[id] = setInterval(() => {
      setDownloads((d) => {
        const p = (d[id].progress || 0) + 0.03 + Math.random() * 0.04;
        if (p >= 1) {
          clearInterval(dlTimers.current[id]);
          setTimeout(() => flash('Downloaded · ' + s.title), 0);
          return { ...d, [id]: { state: 'downloaded', progress: 1 } };
        }
        return { ...d, [id]: { state: 'downloading', progress: p } };
      });
    }, 300);
  }

  function refresh() {
    if (refreshing) return;
    setRefreshing(true);
    setTimeout(() => setRefreshing(false), 1300);
  }

  // ---- nav ----
  function openPlayer(s) { setActive(s); setScreen('player'); }
  function openEdit(s) { setMenuFor(null); setActive(s); setScreen('edit'); }
  function openNew() {
    const blank = {
      id: 'new-' + Date.now(), title: '', fa: 'تمرین تازه', description: '',
      difficulty: 2, isUserCreated: true, accent: 'gold', download: 'none',
      items: [window.PAHLEVANI.mkItem('narmesh'), window.PAHLEVANI.mkItem('shena'), window.PAHLEVANI.mkItem('payan')],
      __isNew: true,
    };
    setActive(blank); setScreen('edit');
  }

  function saveSession(edited, meta) {
    setSessions((list) => {
      const existing = list.find((s) => s.id === edited.id && !meta.wasServer);
      if (existing) {
        return list.map((s) => (s.id === edited.id ? { ...edited } : s));
      }
      // server copy or brand new → create user-owned record
      const copy = { ...edited, id: meta.wasServer ? 'mine-' + Date.now() : edited.id, accent: edited.accent || 'gold' };
      setDownloads((d) => ({ ...d, [copy.id]: { state: 'downloaded', progress: 1 } }));
      return [copy, ...list];
    });
    setScreen('list');
    flash(meta.wasServer ? 'Saved your copy to “Yours”' : 'Session saved');
  }

  function doDelete(s) {
    setConfirmDel(null); setMenuFor(null);
    setSessions((list) => list.filter((x) => x.id !== s.id));
    flash('Deleted · ' + s.title);
  }

  // ---- expose tweak keys for host ----
  React.useEffect(() => {
    window.parent && window.parent.postMessage({ type: '__edit_mode_set_keys', keys: Object.keys(TWEAK_DEFAULTS) }, '*');
  }, []);

  const accentMap = { dark: '#0b0805', light: '#100c06' };

  return (
    <div style={{ height: '100vh', display: 'grid', placeItems: 'center', padding: 12, overflow: 'hidden' }}>
      <div style={{ width: 392 * scale, height: 850 * scale, position: 'relative' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, transform: `scale(${scale})`, transformOrigin: 'top left' }}>
      <DeviceShell theme={theme}>
        {screen === 'list' && (
          <SessionList
            sessions={sessions} downloads={downloads} layout={t.cardLayout}
            refreshing={refreshing} onRefresh={refresh}
            onOpen={openPlayer} onMenu={setMenuFor} onDownload={toggleDownload} onNew={openNew}
            theme={theme} onToggleTheme={() => setTweak('dark', !t.dark)}
          />
        )}
        {screen === 'player' && active && (
          <Player session={active} repFx={t.repFx} showMedia={t.showMedia} onBack={() => setScreen('list')} onEdit={openEdit} />
        )}
        {screen === 'edit' && active && (
          <EditSession session={active} onCancel={() => setScreen(active.__fromPlayer ? 'player' : 'list')} onSave={saveSession} />
        )}

        {/* in-app theme toggle floats over list */}
        {screen === 'list' && (
          <button onClick={() => setTweak('dark', !t.dark)} title="Toggle theme" style={{
            position: 'absolute', top: 16, right: 62, width: 40, height: 40, borderRadius: 99,
            display: 'grid', placeItems: 'center', color: 'var(--on-muted)', background: 'var(--surface-2)', zIndex: 4,
          }}>
            {theme === 'dark'
              ? <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="10" cy="10" r="4"/><path d="M10 1v2M10 17v2M1 10h2M17 10h2M3.5 3.5l1.4 1.4M15.1 15.1l1.4 1.4M16.5 3.5l-1.4 1.4M4.9 15.1l-1.4 1.4" strokeLinecap="round"/></svg>
              : <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M16 11.5A6.5 6.5 0 0 1 8.5 4a6.5 6.5 0 1 0 7.5 7.5z"/></svg>}
          </button>
        )}

        {/* overflow bottom sheet */}
        {menuFor && (
          <MenuSheet session={menuFor} dl={downloads[menuFor.id]}
            onClose={() => setMenuFor(null)}
            onEdit={() => openEdit(menuFor)}
            onDownload={() => { toggleDownload(menuFor); setMenuFor(null); }}
            onDelete={() => setConfirmDel(menuFor)} />
        )}

        {/* delete confirm */}
        {confirmDel && (
          <ConfirmDialog
            title={'Delete “' + confirmDel.title + '”?'}
            body="This removes your session from this device. This can’t be undone."
            confirmLabel="Delete" onConfirm={() => doDelete(confirmDel)} onCancel={() => setConfirmDel(null)} />
        )}

        {/* toast */}
        {toast && (
          <div style={{ position: 'absolute', left: 16, right: 16, bottom: 34, zIndex: 30, display: 'flex', justifyContent: 'center', pointerEvents: 'none' }}>
            <div style={{ background: 'var(--on-surface)', color: 'var(--bg)', padding: '11px 18px', borderRadius: 13, fontSize: 13, fontWeight: 600, boxShadow: 'var(--shadow-pop)', animation: 'fadeUp .25s var(--ease-emph)', maxWidth: '92%' }}>{toast}</div>
          </div>
        )}
      </DeviceShell>
      </div>
      </div>

      {/* tweaks */}
      <TweaksPanel>
        <TweakSection label="Appearance" />
        <TweakToggle label="Dark mode" value={t.dark} onChange={(v) => setTweak('dark', v)} />
        <TweakRadio label="Card layout" value={t.cardLayout} options={['banner', 'compact']} onChange={(v) => setTweak('cardLayout', v)} />
        <TweakSection label="Player" />
        <TweakToggle label="Show exercise media" value={t.showMedia} onChange={(v) => setTweak('showMedia', v)} />
        <TweakRadio label="Rep feedback" value={t.repFx} options={['bold', 'pulse', 'minimal']} onChange={(v) => setTweak('repFx', v)} />
      </TweaksPanel>
    </div>
  );
}

// ---------- Overflow bottom sheet ----------
function MenuSheet({ session, dl, onClose, onEdit, onDownload, onDelete }) {
  const downloaded = dl && dl.state === 'downloaded';
  const downloading = dl && dl.state === 'downloading';
  const rows = [
    { icon: 'edit', label: session.isUserCreated ? 'Edit session' : 'Edit a copy', onClick: onEdit },
    { icon: downloaded ? 'check' : 'download', label: downloaded ? 'Remove download' : downloading ? 'Downloading…' : 'Download', onClick: onDownload, dim: downloading },
  ];
  if (session.isUserCreated) rows.push({ icon: 'trash', label: 'Delete', onClick: onDelete, danger: true });

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 25, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'var(--scrim)', animation: 'scrimIn .2s' }} />
      <div style={{ position: 'relative', background: 'var(--surface)', borderRadius: '26px 26px 0 0', padding: '12px 12px 22px', animation: 'sheetUp .3s var(--ease-emph)' }}>
        <div style={{ width: 36, height: 4, borderRadius: 9, background: 'var(--border)', margin: '0 auto 8px' }} />
        <div style={{ padding: '8px 12px 10px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 17, color: 'var(--on-surface)' }}>{session.title}</span>
          {session.isUserCreated && <YoursChip />}
        </div>
        {rows.map((r, i) => (
          <button key={i} onClick={() => { if (!r.dim) { r.onClick(); } }} style={{
            width: '100%', display: 'flex', alignItems: 'center', gap: 16, padding: '14px 14px', borderRadius: 14,
            color: r.danger ? 'var(--secondary)' : 'var(--on-surface)', opacity: r.dim ? 0.5 : 1, textAlign: 'left',
          }}>
            <Icon name={r.icon} size={22} color={r.danger ? 'var(--secondary)' : 'var(--on-muted)'} />
            <span style={{ fontSize: 15.5, fontWeight: 600 }}>{r.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function ConfirmDialog({ title, body, confirmLabel, onConfirm, onCancel }) {
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 40, display: 'grid', placeItems: 'center', padding: 28 }}>
      <div onClick={onCancel} style={{ position: 'absolute', inset: 0, background: 'var(--scrim)', animation: 'scrimIn .2s' }} />
      <div style={{ position: 'relative', background: 'var(--surface)', borderRadius: 26, padding: '24px 22px 18px', width: '100%', boxShadow: 'var(--shadow-pop)', animation: 'fadeUp .25s var(--ease-emph)' }}>
        <h3 style={{ margin: '0 0 8px', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 20, color: 'var(--on-surface)' }}>{title}</h3>
        <p style={{ margin: '0 0 20px', fontSize: 14, lineHeight: 1.5, color: 'var(--on-muted)' }}>{body}</p>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button onClick={onCancel} style={{ height: 44, padding: '0 18px', borderRadius: 12, fontWeight: 700, fontSize: 14, color: 'var(--on-surface)', background: 'var(--surface-2)' }}>Cancel</button>
          <button onClick={onConfirm} style={{ height: 44, padding: '0 20px', borderRadius: 12, fontWeight: 700, fontSize: 14, color: '#fff', background: 'var(--secondary)' }}>{confirmLabel}</button>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
