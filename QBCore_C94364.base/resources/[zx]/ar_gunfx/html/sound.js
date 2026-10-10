// أصوات مولّدة بالكود (WebAudio) - بدون ملفات صوت: صدى الطلقات + صفير الرصاص
let ctx = null;
let noise = null;
let master = null;

function audio() {
    if (!ctx) {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
        master = ctx.createGain();
        master.gain.value = 1;
        master.connect(ctx.destination);
        // ضجيج أبيض 2 ثانية نستخدمه كمادة خام
        const len = ctx.sampleRate * 2;
        noise = ctx.createBuffer(1, len, ctx.sampleRate);
        const d = noise.getChannelData(0);
        for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    }
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
}

// صدى طلقة: يتأخر حسب المسافة (سرعة الصوت) ويصير أخفض وأبحّ كلما ابتعد
function echo({ dist, volume, indoor }) {
    const c = audio();
    const delay = indoor ? 0.03 : Math.min(dist / 343, 1.6);
    const tail = indoor ? 0.35 : Math.min(0.7 + dist / 120, 2.0);
    const cutoff = indoor ? 2200 : Math.max(500, 2200 - dist * 10);
    const t0 = c.currentTime + delay;

    const src = c.createBufferSource();
    src.buffer = noise;
    src.playbackRate.value = 0.8 + Math.random() * 0.3;

    const lp = c.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = cutoff;

    const g = c.createGain();
    const peak = Math.max(0, Math.min(1, volume));
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + tail);

    const pan = c.createStereoPanner ? c.createStereoPanner() : null;
    if (pan) pan.pan.value = (Math.random() * 2 - 1) * 0.6;

    src.connect(lp);
    lp.connect(g);
    if (pan) { g.connect(pan); pan.connect(master); } else { g.connect(master); }
    src.start(t0, Math.random());
    src.stop(t0 + tail + 0.05);
}

// صفير رصاصة تعدي من يمك: ضجيج بتردد ينزل بسرعة
function whiz({ volume }) {
    const c = audio();
    const t0 = c.currentTime;
    const dur = 0.28;

    const src = c.createBufferSource();
    src.buffer = noise;

    const bp = c.createBiquadFilter();
    bp.type = "bandpass";
    bp.Q.value = 6;
    bp.frequency.setValueAtTime(4200, t0);
    bp.frequency.exponentialRampToValueAtTime(1100, t0 + dur);

    const g = c.createGain();
    const peak = Math.max(0, Math.min(1, volume));
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + 0.04);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);

    const pan = c.createStereoPanner ? c.createStereoPanner() : null;
    if (pan) {
        const side = Math.random() < 0.5 ? -1 : 1;
        pan.pan.setValueAtTime(side * 0.8, t0);
        pan.pan.linearRampToValueAtTime(-side * 0.8, t0 + dur); // تعدي من جهة لجهة
    }

    src.connect(bp);
    bp.connect(g);
    if (pan) { g.connect(pan); pan.connect(master); } else { g.connect(master); }
    src.start(t0, Math.random());
    src.stop(t0 + dur + 0.05);
}

window.addEventListener("message", ({ data }) => {
    if (!data) return;
    if (data.type === "echo") echo(data);
    else if (data.type === "whiz") whiz(data);
});
