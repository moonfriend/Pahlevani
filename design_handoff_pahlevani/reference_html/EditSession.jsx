/* ============================================================
   Pahlevani — Edit / Create session
   Title, description, difficulty, drag-reorder, per-exercise reps.
   ============================================================ */

const ROW_H = 68;

function EditSession({ session, onCancel, onSave }) {
  const { EX } = window.PAHLEVANI;
  const isNew = session.__isNew;
  const fromServer = !isNew && !session.isUserCreated;

  const [title, setTitle] = React.useState(session.title || '');
  const [desc, setDesc] = React.useState(session.description || '');
  const [difficulty, setDifficulty] = React.useState(session.difficulty || 1);
  const [items, setItems] = React.useState(session.items.map((x) => ({ ...x })));

  // ---- drag reorder ----
  const [drag, setDrag] = React.useState(null); // {from, y, startY, curY}
  const listRef = React.useRef(null);

  function onHandleDown(e, i) {
    e.preventDefault();
    const startY = e.clientY;
    setDrag({ from: i, index: i, startY, curY: startY });
    e.target.setPointerCapture && e.target.setPointerCapture(e.pointerId);
  }
  function onPointerMove(e) {
    if (!drag) return;
    const dy = e.clientY - drag.startY;
    let target = drag.from + Math.round(dy / ROW_H);
    target = Math.max(0, Math.min(items.length - 1, target));
    setDrag((d) => ({ ...d, curY: e.clientY }));
    if (target !== drag.index) {
      setItems((arr) => {
        const next = arr.slice();
        const [moved] = next.splice(drag.index, 1);
        next.splice(target, 0, moved);
        return next;
      });
      setDrag((d) => ({ ...d, index: target }));
    }
  }
  function onPointerUp() { setDrag(null); }

  function setReps(i, delta) {
    setItems((arr) => arr.map((it, k) => {
      if (k !== i) return it;
      const v = Math.max(1, Math.min(99, it.reps + delta));
      return { ...it, reps: v };
    }));
  }
  function resetReps(i) {
    setItems((arr) => arr.map((it, k) => k === i ? { ...it, reps: EX[it.exerciseId].reps } : it));
  }

  const canSave = title.trim().length > 0 && items.length > 0;

  function save() {
    if (!canSave) return;
    onSave({
      ...session,
      title: title.trim(),
      description: desc.trim(),
      difficulty,
      items,
      isUserCreated: true,
      __isNew: false,
    }, { wasServer: fromServer || isNew });
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--bg)' }}
         onPointerMove={onPointerMove} onPointerUp={onPointerUp} onPointerCancel={onPointerUp}>
      {/* app bar */}
      <header style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 12px 6px 6px', flexShrink: 0, borderBottom: '1px solid var(--border-soft)' }}>
        <button onClick={onCancel} style={{ width: 44, height: 44, borderRadius: 99, display: 'grid', placeItems: 'center', color: 'var(--on-surface)' }} title="Cancel">
          <Icon name="close" size={22} />
        </button>
        <div style={{ flex: 1, fontSize: 17, fontWeight: 700, color: 'var(--on-surface)' }}>
          {isNew ? 'New session' : fromServer ? 'Edit a copy' : 'Edit session'}
        </div>
        <button onClick={save} disabled={!canSave} style={{
          height: 40, padding: '0 20px', borderRadius: 99, fontWeight: 700, fontSize: 14.5,
          background: canSave ? 'var(--primary)' : 'var(--surface-3)',
          color: canSave ? 'var(--on-primary)' : 'var(--on-faint)',
        }}>Save</button>
      </header>

      <div className="scroll" style={{ flex: 1, overflowY: 'auto', padding: '16px 18px 40px' }}>
        {fromServer && (
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '12px 14px', borderRadius: 14, background: 'var(--teal-bg)', color: 'var(--teal)', marginBottom: 18, fontSize: 12.5, lineHeight: 1.45, fontWeight: 600 }}>
            <Icon name="bolt" size={18} color="var(--teal)" style={{ marginTop: 1, flexShrink: 0 }} />
            <span>This is a built-in session. Saving creates your own editable copy — it won’t change the original.</span>
          </div>
        )}

        <Field label="Title">
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Session name" style={inputStyle} />
        </Field>
        <Field label="Description">
          <textarea value={desc} onChange={(e) => setDesc(e.target.value)} rows={3} placeholder="What is this session for?" style={{ ...inputStyle, resize: 'none', lineHeight: 1.5 }} />
        </Field>
        <Field label="Difficulty">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '4px 2px' }}>
            <div style={{ display: 'flex', gap: 8 }}>
              {[1, 2, 3, 4, 5].map((i) => (
                <button key={i} onClick={() => setDifficulty(i)} style={{
                  width: 30, height: 30, borderRadius: 9, transform: 'rotate(45deg)',
                  background: i <= difficulty ? 'var(--secondary)' : 'var(--surface-3)',
                  transition: 'background .15s, transform .15s', cursor: 'pointer',
                }} title={`${i} of 5`} />
              ))}
            </div>
            <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--on-muted)', marginLeft: 4 }}>{difficulty} / 5</span>
          </div>
        </Field>

        {/* exercises */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', margin: '22px 2px 10px' }}>
          <span style={{ fontSize: 12.5, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', color: 'var(--on-faint)' }}>Exercises · {items.length}</span>
          <span style={{ fontSize: 12, color: 'var(--on-faint)', fontWeight: 600 }}>drag to reorder</span>
        </div>

        <div ref={listRef} style={{ position: 'relative' }}>
          {items.map((it, i) => {
            const ex = EX[it.exerciseId];
            const custom = it.reps !== ex.reps;
            const isDragging = drag && drag.index === i;
            const offset = isDragging ? (drag.curY - drag.startY) - Math.round((drag.curY - drag.startY) / ROW_H) * ROW_H : 0;
            return (
              <div key={it.exerciseId + '-' + i} style={{
                height: ROW_H, display: 'flex', alignItems: 'center', gap: 10,
                background: isDragging ? 'var(--surface)' : 'var(--surface-2)',
                border: '1px solid ' + (isDragging ? 'var(--primary)' : 'var(--border-soft)'),
                borderRadius: 16, padding: '0 8px 0 4px', marginBottom: 8,
                boxShadow: isDragging ? 'var(--shadow-pop)' : 'none',
                transform: isDragging ? `translateY(${offset}px) scale(1.02)` : 'none',
                transition: isDragging ? 'none' : 'transform .18s var(--ease-emph), box-shadow .18s',
                position: 'relative', zIndex: isDragging ? 5 : 1, touchAction: 'none',
              }}>
                <div onPointerDown={(e) => onHandleDown(e, i)} style={{ width: 36, height: '100%', display: 'grid', placeItems: 'center', cursor: 'grab', color: 'var(--on-faint)', touchAction: 'none' }} title="Drag">
                  <svg width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor">
                    {[5, 9, 13].map((y) => [5, 13].map((x) => <circle key={x + '' + y} cx={x} cy={y} r="1.5" />))}
                  </g></svg>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                    <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--on-surface)' }}>{ex.name}</span>
                    <span className="fa" style={{ fontSize: 13, color: 'var(--on-faint)', fontWeight: 600 }}>{ex.fa}</span>
                  </div>
                  <div style={{ fontSize: 11.5, color: 'var(--on-faint)', fontWeight: 500 }}>{ex.gloss}</div>
                </div>
                {/* rep stepper */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 0, background: custom ? 'var(--rep-cus-bg)' : 'var(--rep-def-bg)', borderRadius: 99, padding: 3 }}>
                  <button onClick={() => setReps(i, -1)} style={stepBtn(custom)} title="Fewer reps">−</button>
                  <button onClick={() => custom && resetReps(i)} title={custom ? 'Reset to default' : 'Default reps'} style={{
                    minWidth: 34, textAlign: 'center', fontSize: 14, fontWeight: 800, fontVariantNumeric: 'tabular-nums',
                    color: custom ? 'var(--rep-custom)' : 'var(--rep-default)', cursor: custom ? 'pointer' : 'default', background: 'none',
                  }}>{it.reps}</button>
                  <button onClick={() => setReps(i, +1)} style={stepBtn(custom)} title="More reps">+</button>
                </div>
              </div>
            );
          })}
        </div>
        <p style={{ fontSize: 11.5, color: 'var(--on-faint)', margin: '4px 2px 0', lineHeight: 1.5 }}>
          <span style={{ color: 'var(--rep-default)', fontWeight: 700 }}>Green</span> reps are the exercise default · <span style={{ color: 'var(--rep-custom)', fontWeight: 700 }}>orange</span> means you’ve customised it. Tap a custom number to reset.
        </p>
      </div>
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ display: 'block', fontSize: 12.5, fontWeight: 700, color: 'var(--on-muted)', marginBottom: 7, letterSpacing: 0.2 }}>{label}</label>
      {children}
    </div>
  );
}

const inputStyle = {
  width: '100%', boxSizing: 'border-box', padding: '13px 14px', borderRadius: 14,
  border: '1.5px solid var(--border)', background: 'var(--surface)', color: 'var(--on-surface)',
  fontSize: 15, fontFamily: 'var(--font-ui)', fontWeight: 500, outline: 'none',
};
function stepBtn(custom) {
  return {
    width: 30, height: 30, borderRadius: 99, fontSize: 19, fontWeight: 700, lineHeight: 1,
    color: custom ? 'var(--rep-custom)' : 'var(--rep-default)', background: 'var(--surface)',
    display: 'grid', placeItems: 'center',
  };
}

Object.assign(window, { EditSession });
