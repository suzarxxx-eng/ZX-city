/* OG انترو — شاشة تحميل بستايل روكستار */
const $ = (s) => document.querySelector(s);

/* ---------- الصور ---------- */
// type: map = لقطة جوية من خريطة GTA (x,y إحداثيات اللعبة) | image | video
const SLIDES = [
    { type: "map", x: -110, y: -820, en: "DOWNTOWN", ar: "قلب المدينة", tint: "sunset" },
    { type: "image", src: "../assets/station.png", en: "STRAWBERRY", ar: "الليل هنا ما ينام", tint: "night" },
    { type: "map", x: 690, y: 1120, en: "VINEWOOD HILLS", ar: "تلال الشهرة", tint: "gold" },
    { type: "map", x: -1620, y: -1080, en: "DEL PERRO", ar: "على البحر", tint: "sunset" },
    { type: "video", src: "../assets/city.mp4", en: "LOS SANTOS", ar: "مدينة الأحلام... والخطر", tint: "night" },
    { type: "map", x: -1150, y: -2720, en: "LSIA", ar: "مطار لوس سانتوس", tint: "cool" },
    { type: "map", x: 1820, y: 3700, en: "SANDY SHORES", ar: "الصحرا ما ترحم", tint: "gold" },
    { type: "map", x: 470, y: 5560, en: "MOUNT CHILIAD", ar: "قمة الجبل", tint: "cool" },
    { type: "map", x: -260, y: 6290, en: "PALETO BAY", ar: "آخر الخريطة", tint: "sunset" },
];
const TINTS = {
    sunset: "linear-gradient(160deg,rgba(255,140,60,.55),rgba(120,40,120,.45))",
    gold: "linear-gradient(160deg,rgba(255,200,90,.5),rgba(90,50,20,.35))",
    cool: "linear-gradient(160deg,rgba(60,140,255,.45),rgba(20,20,60,.45))",
    night: "linear-gradient(160deg,rgba(40,80,200,.35),rgba(150,30,60,.35))",
};
const SLIDE_TIME = 8500;

// صور خريطة روكستار (نفس اللي بالـ MDT)
const TILE_Z = 6, K = 32; // zoom الصورة، والتكبير المقابل
function mapArt(x, y) {
    const px = (0.0275 * x + 116.5) * K, py = (-0.0275 * y + 237.5) * K;
    const cols = 8, rows = 6;
    const tx0 = Math.floor(px / 256) - 4, ty0 = Math.floor(py / 256) - 3;
    const art = document.createElement("div");
    art.className = "art";
    const grid = document.createElement("div");
    grid.className = "tiles";
    grid.style.gridTemplateColumns = `repeat(${cols},256px)`;
    for (let r = 0; r < rows; r++)
        for (let c = 0; c < cols; c++) {
            const img = new Image();
            img.src = `https://s.rsg.sc/sc/images/games/GTAV/map/render/${TILE_Z}/${tx0 + c}/${ty0 + r}.jpg`;
            img.onerror = () => { img.style.visibility = "hidden"; };
            grid.appendChild(img);
        }
    art.appendChild(grid);
    const cx = px - tx0 * 256, cy = py - ty0 * 256; // النقطة بنص الشاشة
    art.style.width = cols * 256 + "px";
    art.style.height = rows * 256 + "px";
    art.style.marginLeft = -cx + "px";
    art.style.marginTop = -cy + "px";
    art.style.transformOrigin = `${cx}px ${cy}px`;
    return art;
}

function buildSlide(s) {
    const el = document.createElement("div");
    el.className = "slide";
    let mover;
    if (s.type === "map") {
        mover = mapArt(s.x, s.y);
    } else if (s.type === "image") {
        mover = document.createElement("img");
        mover.className = "full"; mover.src = s.src;
    } else {
        mover = document.createElement("video");
        mover.className = "full"; mover.src = s.src; mover.muted = true; mover.loop = true; mover.playsInline = true;
    }
    el.appendChild(mover);
    const g = document.createElement("div");
    g.className = "grade"; g.style.background = TINTS[s.tint] || TINTS.sunset;
    el.appendChild(g);
    el._mover = mover;
    return el;
}

// حركة كاميرا بطيئة (Ken Burns)
function kenBurns(s, el) {
    const m = el._mover;
    const dir = Math.random() < 0.5 ? -1 : 1;
    const dx = (20 + Math.random() * 40) * dir, dy = (Math.random() * 30 - 15);
    if (s.type === "map") {
        const base = Math.max(innerWidth / 1500, innerHeight / 900) * 1.05;
        m.animate([
            { transform: `translate(0px,0px) scale(${base})` },
            { transform: `translate(${dx * 3}px,${dy * 3}px) scale(${base * 1.18})` },
        ], { duration: SLIDE_TIME + 2000, easing: "linear", fill: "forwards" });
    } else {
        if (m.play) m.play().catch(() => {});
        m.animate([
            { transform: "scale(1.06) translate(0,0)" },
            { transform: `scale(1.18) translate(${dx / 10}%,${dy / 10}%)` },
        ], { duration: SLIDE_TIME + 2000, easing: "linear", fill: "forwards" });
    }
}

const box = $("#slides");
let idx = -1, current = null;
function next() {
    idx = (idx + 1) % SLIDES.length;
    const s = SLIDES[idx];
    const el = buildSlide(s);
    box.appendChild(el);
    kenBurns(s, el);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("on")));
    const old = current;
    current = el;
    if (old) setTimeout(() => { if (old._mover.pause) old._mover.pause(); old.remove(); }, 1800);
    // اسم المكان
    const p = $("#place");
    p.classList.remove("on");
    setTimeout(() => { $("#placeEn").textContent = s.en; $("#placeAr").textContent = s.ar; p.classList.add("on"); }, 700);
}
next();
setInterval(next, SLIDE_TIME);

/* ---------- حبيبات الفلم ---------- */
(function grain() {
    const c = $("#grain"), ctx = c.getContext("2d");
    c.width = 320; c.height = 180;
    const img = ctx.createImageData(320, 180);
    setInterval(() => {
        for (let i = 0; i < img.data.length; i += 4) {
            const v = (Math.random() * 255) | 0;
            img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255;
        }
        ctx.putImageData(img, 0, 0);
    }, 80);
})();

/* ---------- النصايح ---------- */
const TIPS = [
    "افتح الحقيبة بزر <kbd>TAB</kbd>",
    "زر <kbd>ALT</kbd> يطلعلك العين، باوع على أي شي حتى تتفاعل وياه",
    "<kbd>F1</kbd> يفتح القائمة الدائرية: السيارة، النوافذ، المقاعد، والمحرك",
    "رتّب عدادات الواجهة وين ما تريد بزر <kbd>U</kbd>",
    "الأمن العام: <kbd>K</kbd> يفتح الـ MDT و <kbd>G</kbd> يحدد آخر بلاغ",
    "إذا انصبت، اضغط <kbd>E</kbd> حتى تطلب مسعف",
    "حزام الأمان بزر <kbd>B</kbd>، ومن غيره تطير من الجامة",
    "احترم القوانين وخلي الرول بلاي واقعي، المدينة إلها حكامها",
    "رتب الأمن العام تنشاف بزر <kbd>F9</kbd>",
];
let tipI = Math.floor(Math.random() * TIPS.length);
function showTip() {
    const t = $("#tip");
    t.classList.add("out");
    setTimeout(() => { t.innerHTML = TIPS[tipI % TIPS.length]; tipI++; t.classList.remove("out"); }, 500);
}
showTip();
setInterval(showTip, 6500);

/* ---------- التحميل ---------- */
let pct = 0, count = 0, done = 0, mapCount = 0, mapDone = 0;
function setPct(v, state) {
    v = Math.max(pct, Math.min(100, Math.round(v)));
    pct = v;
    $("#lPct").textContent = v + "%";
    $("#bar").style.width = v + "%";
    if (state) $("#lState").textContent = state;
    else $("#lState").textContent = v < 40 ? "جاري تحميل الملفات" : v < 85 ? "جاري تجهيز المدينة" : "تقريباً خلصنا";
}
const handlers = {
    loadProgress(d) { setPct((d.loadFraction || 0) * 100); },
    startInitFunctionOrder(d) { count = d.count || count; },
    initFunctionInvoking(d) { if (count) setPct((d.idx / count) * 60); },
    startDataFileEntries(d) { mapCount = d.count || mapCount; },
    performMapLoadFunction() { mapDone++; if (mapCount) setPct(60 + (mapDone / mapCount) * 40); },
};
window.addEventListener("message", (e) => { const h = handlers[e.data && e.data.eventName]; if (h) h(e.data); });

/* ---------- الموسيقى ---------- */
const music = $("#music");
let muted = false;
try { muted = localStorage.getItem("ogMute") === "1"; } catch (e) {}
music.volume = 0.18;
function applyMute() {
    music.muted = muted;
    $("#mute").classList.toggle("off", muted);
    if (!muted) music.play().catch(() => {});
}
applyMute();
$("#mute").addEventListener("click", () => {
    muted = !muted;
    try { localStorage.setItem("ogMute", muted ? "1" : "0"); } catch (e) {}
    applyMute();
});

/* معاينة خارج اللعبة: نحاكي التحميل */
if (typeof GetParentResourceName !== "function" && !window.nuiHandoverData) {
    let f = 0;
    const t = setInterval(() => { f += 0.012; handlers.loadProgress({ loadFraction: f }); if (f >= 1) clearInterval(t); }, 300);
}
