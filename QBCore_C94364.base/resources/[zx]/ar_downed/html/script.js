/* تأثير السقوط: إطار دم ينبض ويا دقات قلب مصنوعة بالصوت (بدون ملفات صوت) */
const fx = document.getElementById("fx");
const flash = document.getElementById("flash");
const dropsBox = document.getElementById("drops");

let ctx = null;
let active = false;
let started = 0;
let cfg = { enabled: true, startBpm: 115, endBpm: 42, slowDown: 90, volume: 0.9 };
let beatTimer = null;
let dropTimer = null;

function audio() {
    if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
}

// دقة واحدة: "لَب" قوية وبعدها "دَب" أخف
function thump(time, strength) {
    const a = audio();
    const osc = a.createOscillator();
    const gain = a.createGain();
    const filter = a.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 140;
    osc.type = "sine";
    osc.frequency.setValueAtTime(70, time);
    osc.frequency.exponentialRampToValueAtTime(38, time + 0.16);
    gain.gain.setValueAtTime(0.0001, time);
    gain.gain.exponentialRampToValueAtTime(strength * cfg.volume, time + 0.018);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.22);
    osc.connect(filter).connect(gain).connect(a.destination);
    osc.start(time);
    osc.stop(time + 0.25);
}

// طنين الأذن: صفير عالي يخفت خلال ثواني
function ringing() {
    const a = audio();
    const now = a.currentTime;
    const osc = a.createOscillator();
    const gain = a.createGain();
    osc.type = "sine";
    osc.frequency.value = 3800;
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.06 * cfg.volume, now + 0.08);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 7);
    osc.connect(gain).connect(a.destination);
    osc.start(now);
    osc.stop(now + 7.2);
}

/* ---------- شريط تخطيط القلب (ECG) ---------- */
const canvas = document.getElementById("ecg");
const g = canvas.getContext("2d");
const bpmVal = document.getElementById("bpmVal");
const heart = document.querySelector("#bpm .hrt");
let trace = [];
let lastBeatAt = -10000;
let prevBeatAt = -10000;
let lastFrame = 0;
let rafId = null;

const gauss = (t, mu, s) => Math.exp(-((t - mu) ** 2) / (2 * s * s));
// شكل نبضة حقيقية: P ثم QRS (الشوكة) ثم T
function ecgValue(t) {
    if (t < 0 || t > 0.6) return 0;
    return 0.1 * gauss(t, 0.05, 0.022)
        - 0.12 * gauss(t, 0.125, 0.008)
        + 1.0 * gauss(t, 0.145, 0.009)
        - 0.28 * gauss(t, 0.165, 0.01)
        + 0.22 * gauss(t, 0.33, 0.045);
}

function resizeEcg() {
    canvas.width = Math.floor(canvas.clientWidth * devicePixelRatio);
    canvas.height = Math.floor(canvas.clientHeight * devicePixelRatio);
    trace = new Array(canvas.width).fill(0);
}
window.addEventListener("resize", resizeEcg);

function drawEcg(now) {
    if (!active) return;
    if (!lastFrame) lastFrame = now;
    const dt = Math.min(1.0, (now - lastFrame) / 1000);
    lastFrame = now;
    const w = canvas.width, h = canvas.height;
    if (w === 0) { resizeEcg(); rafId = requestAnimationFrame(drawEcg); return; }

    // الخط يمشي من اليمين لليسار (الشاشة كلها = 3.5 ثانية)
    const speed = w / 3.5;
    const n = Math.max(1, Math.round(speed * dt));
    for (let i = 0; i < n; i++) {
        const tMs = now - ((n - 1 - i) / n) * dt * 1000;
        // نحسب من آخر دقة قبل هاي اللحظة (حتى لو الإطارات تأخرت ما تضيع دقات)
        let since = (tMs - lastBeatAt) / 1000;
        if (since < 0 && prevBeatAt > -10000) since = (tMs - prevBeatAt) / 1000;
        trace.push(ecgValue(since) + (Math.random() - 0.5) * 0.015);
    }
    if (trace.length > w) trace.splice(0, trace.length - w);

    g.clearRect(0, 0, w, h);
    // شبكة خفيفة
    g.strokeStyle = "rgba(255,60,60,.08)";
    g.lineWidth = 1;
    const step = h / 4;
    for (let y = step; y < h; y += step) { g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke(); }

    const mid = h * 0.62, amp = h * 0.45;
    g.beginPath();
    trace.forEach((v, x) => {
        const y = mid - v * amp;
        if (x === 0) g.moveTo(x, y); else g.lineTo(x, y);
    });
    g.strokeStyle = "#ff3b3b";
    g.lineWidth = 2.2 * devicePixelRatio;
    g.shadowColor = "rgba(255,0,0,.9)";
    g.shadowBlur = 12 * devicePixelRatio;
    g.stroke();
    g.shadowBlur = 0;

    // نقطة مضيئة براس الخط
    const lastY = mid - trace[trace.length - 1] * amp;
    g.fillStyle = "#fff";
    g.beginPath();
    g.arc(trace.length - 1, lastY, 3 * devicePixelRatio, 0, Math.PI * 2);
    g.fill();

    rafId = requestAnimationFrame(drawEcg);
}

function progress() {
    const secs = (Date.now() - started) / 1000;
    return Math.min(1, secs / Math.max(1, cfg.slowDown));
}

function beat() {
    if (!active) return;
    const p = progress();
    const bpm = cfg.startBpm + (cfg.endBpm - cfg.startBpm) * p;
    const interval = 60000 / bpm;

    fx.style.setProperty("--k", (0.35 + p * 0.65).toFixed(3));

    // الشوكة بالشريط تنزل ويا صوت الدقة بالضبط
    prevBeatAt = lastBeatAt;
    lastBeatAt = performance.now() - 125;
    bpmVal.textContent = Math.round(bpm);
    heart.classList.add("pump");
    setTimeout(() => heart.classList.remove("pump"), 150);

    if (cfg.enabled) {
        const t = audio().currentTime + 0.02;
        thump(t, 0.9);
        thump(t + 0.26 * Math.min(1, 70 / bpm), 0.55);
    }
    // نبضة الإطار ويا الدقة
    fx.style.setProperty("--beat", "1");
    setTimeout(() => fx.style.setProperty("--beat", "0.35"), 140);
    setTimeout(() => fx.style.setProperty("--beat", "0"), 420);

    beatTimer = setTimeout(beat, interval);
}

function spawnDrop() {
    if (!active) return;
    const d = document.createElement("i");
    d.className = "drop";
    d.style.left = Math.random() * 100 + "vw";
    d.style.height = 4 + Math.random() * 10 + "vh";
    d.style.opacity = (0.4 + Math.random() * 0.5).toFixed(2);
    d.style.animationDuration = 2.5 + Math.random() * 3 + "s";
    dropsBox.appendChild(d);
    setTimeout(() => d.remove(), 6000);
    dropTimer = setTimeout(spawnDrop, 500 + Math.random() * 1400);
}

function start(data) {
    if (active) return;
    active = true;
    started = Date.now();
    if (data.heartbeat) cfg = Object.assign(cfg, data.heartbeat);
    fx.classList.remove("hidden");
    flash.classList.remove("go");
    void flash.offsetWidth;
    flash.classList.add("go");
    if (data.ringing) ringing();
    resizeEcg();
    lastFrame = 0;
    cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(drawEcg);
    beat();
    spawnDrop();
}

function stop() {
    active = false;
    cancelAnimationFrame(rafId);
    clearTimeout(beatTimer);
    clearTimeout(dropTimer);
    dropsBox.replaceChildren();
    fx.classList.add("hidden");
    fx.style.setProperty("--k", "0.35");
    fx.style.setProperty("--beat", "0");
    setInfo({ requested: false, mode: null });
}

/* معلومات الإسعاف (تجي من qb-ambulancejob بالعربي بدل نصوص اللعبة الإنكليزية) */
const medic = document.getElementById("medic");
const timer = document.getElementById("timer");

function setInfo(info) {
    if (!info) return;
    const requested = !!info.requested;
    medic.classList.toggle("done", requested);
    medic.querySelector("kbd").textContent = requested ? "✓" : "E";
    medic.querySelector("span").textContent = requested ? "تم طلب المسعف" : "طلب مسعف";

    const t = Math.max(0, Number(info.time) || 0);
    timer.classList.remove("hidden");
    timer.replaceChildren();
    const add = (txt, bold) => {
        const el = document.createElement(bold ? "b" : "span");
        el.textContent = txt;
        timer.appendChild(el);
    };
    if (info.mode === "bleed") {
        add("تنزف • باقي ");
        add(t, true);
        add(" ثانية");
    } else if (info.mode === "dead") {
        add("تكدر ترجع بعد ");
        add(t, true);
        add(" ثانية");
    } else if (info.mode === "respawn") {
        add("اضغط مطولاً ");
        add("E", true);
        add(" للرجوع للمستشفى");
        if (info.cost) {
            add(" • ");
            add("$" + info.cost, true);
        }
    } else {
        timer.classList.add("hidden");
    }
}

window.addEventListener("message", ({ data }) => {
    if (!data) return;
    if (data.action === "info") { setInfo(data.info); return; }
    if (data.action !== "down") return;
    if (data.state) start(data);
    else stop();
});
