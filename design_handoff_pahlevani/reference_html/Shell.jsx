/* ============================================================
   Pahlevani — themed device shell (Android / Material 3 vibe)
   Status bar + gesture nav, fully theme-token driven.
   ============================================================ */

function StatusBar() {
  return (
    <div style={{
      height: 36, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 22px', position: 'relative', flexShrink: 0, color: 'var(--on-surface)',
      fontSize: 13, fontWeight: 600, letterSpacing: 0.2,
    }}>
      <span>6:30</span>
      <div style={{
        position: 'absolute', left: '50%', top: 11, transform: 'translateX(-50%)',
        width: 9, height: 9, borderRadius: 99, background: '#000', opacity: 0.85,
      }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        {/* signal */}
        <svg width="16" height="12" viewBox="0 0 16 12"><g fill="currentColor">
          <rect x="0" y="8" width="2.4" height="4" rx="0.6" /><rect x="3.6" y="5.5" width="2.4" height="6.5" rx="0.6" />
          <rect x="7.2" y="3" width="2.4" height="9" rx="0.6" /><rect x="10.8" y="0.5" width="2.4" height="11.5" rx="0.6" />
        </g></svg>
        {/* wifi */}
        <svg width="16" height="12" viewBox="0 0 16 12"><path d="M8 11.2 1 4.2a9.9 9.9 0 0 1 14 0z" fill="currentColor" /></svg>
        {/* battery */}
        <svg width="22" height="12" viewBox="0 0 22 12">
          <rect x="0.6" y="0.6" width="18" height="10.8" rx="2.6" fill="none" stroke="currentColor" strokeWidth="1.1" opacity="0.5" />
          <rect x="2.2" y="2.2" width="12" height="7.6" rx="1.3" fill="currentColor" />
          <rect x="19.4" y="4" width="1.8" height="4" rx="0.9" fill="currentColor" opacity="0.5" />
        </svg>
      </div>
    </div>
  );
}

function GestureNav() {
  return (
    <div style={{ height: 26, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <div style={{ width: 128, height: 5, borderRadius: 3, background: 'var(--on-surface)', opacity: 0.34 }} />
    </div>
  );
}

function DeviceShell({ theme, children }) {
  return (
    <div className={'theme-' + theme} style={{
      width: 392, height: 850, position: 'relative',
      borderRadius: 46, padding: 5,
      background: theme === 'dark'
        ? 'linear-gradient(150deg,#3a3024,#181208)'
        : 'linear-gradient(150deg,#cdbfa3,#9e8d70)',
      boxShadow: '0 40px 90px -20px rgba(0,0,0,0.65), 0 0 0 1px rgba(0,0,0,0.25)',
    }}>
      <div style={{
        width: '100%', height: '100%', borderRadius: 42, overflow: 'hidden',
        background: 'var(--bg)', display: 'flex', flexDirection: 'column',
        position: 'relative', color: 'var(--on-surface)',
      }}>
        <StatusBar />
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {children}
        </div>
        <GestureNav />
      </div>
    </div>
  );
}

Object.assign(window, { DeviceShell, StatusBar, GestureNav });
