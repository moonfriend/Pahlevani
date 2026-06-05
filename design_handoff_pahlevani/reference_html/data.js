/* ============================================================
   Pahlevani — sample data
   Varzesh-e Bastani (Persian warrior fitness) sessions.
   Exercises use authentic Zurkhaneh movement names.
   durationSeconds / repetitionsDefault are tuned so a rep
   ticks every ~3s — making the rep moment demoable live.
   ============================================================ */
(function () {
  // ---- Exercise library (the "what") ----
  // media: how the move is demonstrated on screen.
  //   type 'video' → looping muted clip (src). 'photo' → still image.
  //   'slot'  → fillable placeholder (user drops a real photo).
  //   'none'  → no asset yet → Persian-pattern fallback.
  // src/poster are wired for production; the prototype demonstrates with
  // drop-slots since the runtime can render user photos live.
  const EX = {
    niyayesh:  { id:'niyayesh',  name:'Niyâyesh',     fa:'نیایش',      gloss:'Invocation & breath',     author:'Morshed Karimi', reps:8,  dur:40, type:'breath',   media:{ type:'none' } },
    narmesh:   { id:'narmesh',   name:'Narmesh',      fa:'نرمش',       gloss:'Limbering warm-up',       author:'Morshed Karimi', reps:12, dur:48, type:'warmup',   media:{ type:'video', src:'', poster:'' } },
    shena:     { id:'shena',     name:'Shenâ',        fa:'شنا',        gloss:'Push-ups on the takhteh', author:'Morshed Davari', reps:16, dur:48, type:'strength', media:{ type:'slot' } },
    shenatiz:  { id:'shenatiz',  name:'Shenâ-ye Tiz', fa:'شنای تیز',   gloss:'Fast cadence push-ups',   author:'Morshed Davari', reps:24, dur:48, type:'strength', media:{ type:'photo', src:'' } },
    sang:      { id:'sang',      name:'Sang-giri',    fa:'سنگ گرفتن',  gloss:'Lifting the shields',     author:'Morshed Davari', reps:10, dur:50, type:'strength', media:{ type:'photo', src:'' } },
    milbazi:   { id:'milbazi',   name:'Mil-bâzi',     fa:'میل‌بازی',   gloss:'Swinging the clubs',      author:'Morshed Sattari', reps:30, dur:90, type:'club',     media:{ type:'video', src:'', poster:'' } },
    milgiri:   { id:'milgiri',   name:'Mil-giri',     fa:'میل‌گیری',   gloss:'Heavy club hold & throw', author:'Morshed Sattari', reps:20, dur:80, type:'club',     media:{ type:'photo', src:'' } },
    charkh:    { id:'charkh',    name:'Charkh',       fa:'چرخ',        gloss:'Whirling turns',          author:'Morshed Sattari', reps:14, dur:56, type:'spin',     media:{ type:'video', src:'', poster:'' } },
    kabbadeh:  { id:'kabbadeh',  name:'Kabbâdeh',     fa:'کباده',      gloss:'The iron bow',            author:'Morshed Karimi', reps:18, dur:72, type:'strength', media:{ type:'photo', src:'' } },
    pazadan:   { id:'pazadan',   name:'Pâ-zadan',     fa:'پا زدن',     gloss:'Rhythmic footwork',       author:'Morshed Sattari', reps:32, dur:64, type:'footwork', media:{ type:'video', src:'', poster:'' } },
    payan:     { id:'payan',     name:'Payâni',       fa:'پایانی',     gloss:'Closing & cool-down',     author:'Morshed Karimi', reps:8,  dur:40, type:'breath',   media:{ type:'none' } },
  };

  // helper: build an item (prescription). reps omitted => default.
  const it = (exId, reps) => ({ exerciseId: exId, reps: reps == null ? EX[exId].reps : reps });

  // ---- Sessions (the "ordering") ----
  const SESSIONS = [
    {
      id: 's-foundation',
      title: 'Daily Foundation',
      fa: 'بنیاد روزانه',
      description: 'A gentle, complete circuit for everyday practice. Builds the breath, the wrists and the legs without overreaching.',
      difficulty: 2,
      isUserCreated: false,
      download: 'downloaded',
      accent: 'gold',
      items: [ it('niyayesh'), it('narmesh'), it('shena', 12), it('milbazi', 20), it('charkh'), it('payan') ],
    },
    {
      id: 's-zurkhaneh',
      title: 'House of Strength',
      fa: 'زورخانه',
      description: 'The classic Zurkhaneh ceremony, ordered as the Morshed calls it — from invocation through the clubs to the whirl.',
      difficulty: 3,
      isUserCreated: false,
      download: 'downloading',
      downloadProgress: 0.62,
      accent: 'terracotta',
      items: [ it('niyayesh'), it('narmesh'), it('shena'), it('sang'), it('milbazi'), it('milgiri', 24), it('charkh'), it('payan') ],
    },
    {
      id: 's-champion',
      title: 'Way of the Champion',
      fa: 'راه پهلوان',
      description: 'For the seasoned varzeshkâr. Long sets, heavy clubs and the iron bow. Earn the title of Pahlevân.',
      difficulty: 5,
      isUserCreated: false,
      download: 'none',
      accent: 'teal',
      items: [ it('shenatiz', 30), it('sang', 14), it('milgiri', 28), it('kabbadeh', 24), it('pazadan', 40) ],
    },
    {
      id: 's-mine',
      title: 'My Morning Set',
      fa: 'تمرین صبح من',
      description: 'A short personal warm-up I run before work — light clubs and a few turns to wake the body.',
      difficulty: 1,
      isUserCreated: true,
      download: 'downloaded',
      accent: 'gold',
      items: [ it('narmesh', 8), it('milbazi', 16), it('charkh', 8), it('payan') ],
    },
  ];

  // attach gloss/duration helpers
  function exFor(id) { return EX[id]; }
  function fmtDur(totalSec) {
    const m = Math.round(totalSec / 60);
    if (m < 60) return m + 'm';
    const h = Math.floor(m / 60), r = m % 60;
    return r ? `${h}h ${r}m` : `${h}h`;
  }
  function sessionSeconds(session) {
    return session.items.reduce((acc, item) => {
      const ex = EX[item.exerciseId];
      const perRep = ex.dur / ex.reps;
      return acc + perRep * item.reps;
    }, 0);
  }

  window.PAHLEVANI = { EX, SESSIONS, exFor, fmtDur, sessionSeconds, mkItem: it };
})();
