/* قائمة OG */
const $ = (s, r = document) => r.querySelector(s);
const IN_GAME = typeof GetParentResourceName === "function";
const RES = IN_GAME ? GetParentResourceName() : "og_menu";
const money = (n) => "$" + Math.round(Number(n) || 0).toLocaleString("en-US");
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
let D = null, ROOM = null, ME = 0, TDM = null, view = null;

async function post(n, d = {}) {
    if (!IN_GAME) return MOCK(n, d);
    try {
        const t = await fetch(`https://${RES}/${n}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(d) }).then((r) => r.text());
        let v = JSON.parse(t); if (typeof v === "string") v = JSON.parse(v);
        return v;
    } catch (e) { return null; }
}

/* ---------- أيقونات مليانة (أبيض + تفاصيل بلون الشارة) ---------- */
// K = لون التفاصيل المقصوصة (نفس لون الشارة)
const K = 'fill="var(--k)"', KS = 'fill="none" stroke="var(--k)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';
const gearTeeth = Array.from({ length: 8 }, (_, i) => `<rect x="10.4" y="1.6" width="3.2" height="5" rx="1" transform="rotate(${i * 45} 12 12)"/>`).join("");
const I = {
    shield: `<path d="M12 1.8l8.2 3.3v6.4c0 5.1-3.5 9.3-8.2 10.7-4.7-1.4-8.2-5.6-8.2-10.7V5.1z"/><path ${KS} d="M8.3 12.2l2.6 2.6 5-5.2"/>`,
    chat: `<path d="M19.6 5.2A17 17 0 0 0 15.3 4l-.5 1.1a15.8 15.8 0 0 0-5.6 0L8.7 4a17 17 0 0 0-4.3 1.2C1.7 9.2 1 13.1 1.3 17a17.2 17.2 0 0 0 5.2 2.6l1.1-1.8a11 11 0 0 1-1.7-.8l.4-.3a12.2 12.2 0 0 0 11.4 0l.4.3a11 11 0 0 1-1.7.8l1.1 1.8a17.2 17.2 0 0 0 5.2-2.6c.4-4.5-.7-8.4-3.1-11.8z"/><ellipse ${K} cx="8.6" cy="13.1" rx="1.7" ry="1.9"/><ellipse ${K} cx="15.4" cy="13.1" rx="1.7" ry="1.9"/>`,
    cash: `<rect x="2" y="5.5" width="20" height="13" rx="2.6"/><circle ${K} cx="12" cy="12" r="3.3"/><circle ${K} cx="5.6" cy="12" r="1.1"/><circle ${K} cx="18.4" cy="12" r="1.1"/>`,
    bank: `<path d="M12 2.2l9.5 5.6v1.9h-19V7.8z"/><rect x="4.2" y="10.8" width="2.6" height="7.4" rx=".6"/><rect x="9" y="10.8" width="2.6" height="7.4" rx=".6"/><rect x="13.8" y="10.8" width="2.6" height="7.4" rx=".6"/><rect x="18.6" y="10.8" width="1.6" height="7.4" rx=".6"/><rect x="2.5" y="19.2" width="19" height="2.6" rx="1"/><circle ${K} cx="12" cy="6.4" r="1.3"/>`,
    phone: `<rect x="5.8" y="1.5" width="12.4" height="21" rx="3"/><rect ${K} x="7.6" y="4.2" width="8.8" height="13.6" rx="1"/><rect ${K} x="10.4" y="19.4" width="3.2" height="1.3" rx=".65"/>`,
    cake: `<rect x="2.8" y="4.5" width="18.4" height="17" rx="3"/><rect ${K} x="2.8" y="9" width="18.4" height="1.6"/><rect x="6.6" y="2" width="2.2" height="5" rx="1.1"/><rect x="15.2" y="2" width="2.2" height="5" rx="1.1"/><rect ${K} x="6.4" y="13" width="3" height="3" rx=".7"/><rect ${K} x="10.5" y="13" width="3" height="3" rx=".7"/><rect ${K} x="14.6" y="13" width="3" height="3" rx=".7"/>`,
    target: `<circle cx="12" cy="12" r="10"/><circle ${K} cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="4.2"/><circle ${K} cx="12" cy="12" r="1.6"/>`,
    users: `<circle cx="16.6" cy="7.6" r="3.2" opacity=".6"/><path opacity=".6" d="M12.8 20.5c.3-3.8 1.8-6.3 4.2-6.3 2.9 0 5.1 2.6 5.5 6.3z"/><circle cx="8.6" cy="7.8" r="4"/><path d="M1.6 21.2c.4-4.6 3.3-7.4 7-7.4s6.6 2.8 7 7.4z"/>`,
    map: `<path d="M1.8 5.4l6.5-2.6 7.4 2.8 6.5-2.6v15.6l-6.5 2.6-7.4-2.8-6.5 2.6z"/><path ${KS} stroke-width="1.4" d="M8.3 2.8v15.6M15.7 5.6v15.6"/><path ${K} d="M18.2 7.2c-1.6 0-2.9 1.3-2.9 2.9 0 2.1 2.9 5 2.9 5s2.9-2.9 2.9-5c0-1.6-1.3-2.9-2.9-2.9zm0 3.9a1 1 0 1 1 0-2 1 1 0 0 1 0 2z"/>`,
    car: `<path d="M3.2 12.2l2.1-5.3A2.6 2.6 0 0 1 7.7 5.2h8.6a2.6 2.6 0 0 1 2.4 1.7l2.1 5.3A2.2 2.2 0 0 1 22.3 14v3.6a1.4 1.4 0 0 1-1.4 1.4H3.1a1.4 1.4 0 0 1-1.4-1.4V14a2.2 2.2 0 0 1 1.5-1.8z"/><path ${K} d="M6 11.6l1.5-3.9a.8.8 0 0 1 .8-.5h7.4a.8.8 0 0 1 .8.5l1.5 3.9z"/><circle ${K} cx="6.4" cy="15.2" r="1.4"/><circle ${K} cx="17.6" cy="15.2" r="1.4"/><rect x="3.6" y="18.6" width="3.6" height="3" rx="1.2"/><rect x="16.8" y="18.6" width="3.6" height="3" rx="1.2"/>`,
    brief: `<path d="M8.4 6V4.6a2 2 0 0 1 2-2h3.2a2 2 0 0 1 2 2V6h-2V4.6h-3.2V6z"/><rect x="1.8" y="6" width="20.4" height="15" rx="2.6"/><rect ${K} x="1.8" y="11.4" width="20.4" height="1.6"/><rect x="10" y="10.2" width="4" height="4" rx="1"/>`,
    gear: `${gearTeeth}<circle cx="12" cy="12" r="7.6"/><circle ${K} cx="12" cy="12" r="3.1"/>`,
    exit: `<path d="M3 4.6A2.6 2.6 0 0 1 5.6 2h7.2v20H5.6A2.6 2.6 0 0 1 3 19.4z"/><path fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" d="M15.5 8l4 4-4 4M19.5 12h-9"/>`,
    arrow: `<path fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" d="M15 18l-6-6 6-6"/>`,
    lock: `<path fill="none" stroke="currentColor" stroke-width="2.4" d="M7.5 11V8a4.5 4.5 0 0 1 9 0v3"/><rect x="4" y="10.5" width="16" height="11.5" rx="2.6"/><circle ${K} cx="12" cy="15.6" r="1.7"/><rect ${K} x="11.2" y="16" width="1.6" height="3" rx=".8"/>`,
    star: `<path d="M12 2.2l3 6.2 6.8 1-4.9 4.8 1.2 6.8L12 17.8 5.9 21l1.2-6.8-4.9-4.8 6.8-1z"/>`,
};const icon = (n) => `<svg viewBox="0 0 24 24">${I[n] || ""}</svg>`;
function paintIcons(root = document) { root.querySelectorAll("[data-i]").forEach((e) => (e.innerHTML = icon(e.dataset.i))); }
paintIcons();

/* صور الأسلحة (ظل) */
const GUNS = {
    pistol: `<svg class="gun" viewBox="0 0 120 60"><path d="M8 12h78l5-4h9v15h-6v5H58l-5 7H41l-6 21H20l8-29H8zM40 28h12l-3 6H38z"/></svg>`,
    ak: `<svg class="gun" viewBox="0 0 240 70"><path d="M4 22h40l6-6h58l4-4h86v6h20v8h-20v4H120l-6 4H96c4 10 10 22 20 34l-14 4c-10-12-16-24-20-38H72l-6 18H52l4-18H40l-8 6H6l4-12z"/></svg>`,
    sniper: `<svg class="gun" viewBox="0 0 260 60"><path d="M4 28h44l10-8h70l6 6h124v6H134l-4 4h-30l-8 18H78l6-18H58l-8 6H6z"/><rect x="88" y="6" width="56" height="10" rx="5"/><rect x="104" y="14" width="6" height="8"/><rect x="122" y="14" width="6" height="8"/></svg>`,
    shotgun: `<svg class="gun" viewBox="0 0 240 60"><path d="M4 24h48l10-8h40v6h132v8H104l-4 6H64l-8 16H42l6-16H30l-6 6H6z"/><rect x="112" y="30" width="54" height="10" rx="4"/></svg>`,
};
const MODES = [
    { id: "pistol", label: "مسدس", c: "#3ddc97", sub: "ساحة صغيرة" },
    { id: "ak", label: "AK", c: "#ff8a4c", sub: "ساحة متوسطة" },
    { id: "sniper", label: "سنايبر", c: "#3fd0ff", sub: "ساحة كبيرة" },
    { id: "shotgun", label: "شوزن", c: "#ff4d6d", sub: "ساحة ضيقة" },
];
const WCOL = { pistol: "#3ddc97", ak: "#ff8a4c", sniper: "#3fd0ff", shotgun: "#ff4d6d" };
const WLAB = { pistol: "مسدس", ak: "AK", sniper: "سنايبر", shotgun: "شوزن" };

/* ---------- الساعة: توقيت العراق 12 ساعة ---------- */
function tick() {
    const d = new Date();
    let parts;
    try { parts = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Baghdad", hour: "numeric", minute: "2-digit", hour12: true }).formatToParts(d); }
    catch (e) {
        const u = new Date(d.getTime() + (d.getTimezoneOffset() + 180) * 60000), h = u.getHours();
        parts = [{ type: "hour", value: String(h % 12 || 12) }, { type: "minute", value: String(u.getMinutes()).padStart(2, "0") }, { type: "dayPeriod", value: h < 12 ? "AM" : "PM" }];
    }
    const g = (t) => (parts.find((p) => p.type === t) || {}).value || "";
    $("#tClock").textContent = `${g("hour")}:${g("minute")}`;
    $("#tAmPm").textContent = g("dayPeriod").toUpperCase().startsWith("A") ? "ص" : "م";
    try { $("#tDate").textContent = d.toLocaleDateString("ar-IQ-u-nu-latn", { timeZone: "Asia/Baghdad", weekday: "long", day: "numeric", month: "long" }); }
    catch (e) { $("#tDate").textContent = d.toLocaleDateString("ar-IQ", { weekday: "long", day: "numeric", month: "long" }); }
}
setInterval(tick, 15000); tick();

/* ---------- البيانات ---------- */
function render(d) {
    D = d;
    $("#bTitle").textContent = d.title || "OG";
    $("#bSub").textContent = d.subtitle || "ROLEPLAY";
    $("#tOnline").textContent = `${d.online} / ${d.maxPlayers}`;
    $("#sCops").textContent = d.cops;
    $("#sEms").textContent = d.ems;
    $("#sDiscord").textContent = d.discord || "";

    $("#pName").textContent = d.name;
    $("#pAv").textContent = (d.name || "OG").trim().split(/\s+/).map((w) => w[0]).slice(0, 2).join("").toUpperCase();
    $("#pCash").textContent = money(d.cash);
    $("#pBank").textContent = money(d.bank);
    $("#pPhone").textContent = d.phone || "—";
    $("#pCid").textContent = d.cid;
    $("#pBirth").textContent = d.birth || "—";
    $("#pId").textContent = d.id;

    $("#cCount").textContent = `${(d.vehicles || []).length} سيارة`;
    $("#jName").textContent = d.job || "—";
    $("#jGrade").textContent = (d.grade || "") + (d.callsign ? `  •  ${d.callsign}` : "");
    const duty = $("#jDuty");
    duty.className = "duty" + (d.onduty ? " on" : "");
    duty.innerHTML = `<i></i>${d.onduty ? "بالدوام" : "مو بالدوام"}`;
    renderArena(d.arena);
    renderTdmTile();
}

function renderArena(a) {
    const counts = (a && a.counts) || {};
    let total = 0;
    $("#aList").innerHTML = MODES.map((m) => {
        const n = Number(counts[m.id]) || 0; total += n;
        return `<button type="button" class="aRow" data-m="${m.id}" style="--m:${m.c}">${GUNS[m.id]}<b>${m.label}<br><small>${m.sub}</small></b><span class="n">${n}</span></button>`;
    }).join("");
    $("#aTotal").textContent = total;
    const inside = !!(a && a.inside);
    $("#aList").classList.toggle("hidden", inside);
    $("#aLeave").classList.toggle("hidden", !inside);
    document.querySelectorAll(".aRow").forEach((b) => (b.onclick = () => {
        if (!a) return toast("الأرينا مو شغالة");
        if (ROOM) return toast("اطلع من غرفة التيد ام أول");
        post("arena", { mode: b.dataset.m });
    }));
}
$("#aLeave").onclick = () => post("arenaLeave");

function renderTdmTile() {
    const body = $("#tdmBody");
    if (ROOM) {
        const n = ROOM.players.length;
        body.innerHTML = `<div class="tStat mine"><small>غرفتك</small><b>${esc(ROOM.name)}</b></div>
          <div class="tStat"><small>اللاعبين</small><b style="direction:ltr;text-align:right">${n} / ${ROOM.max}</b></div>
          <div class="tStat"><small>الحالة</small><b>${ROOM.state === "lobby" ? "بالانتظار" : "الجولة شغالة"}</b></div>`;
    } else {
        const rooms = (TDM && TDM.rooms) || [];
        body.innerHTML = `<div class="tStat"><small>غرف مفتوحة</small><b>${rooms.length}</b></div>
          <div class="tStat"><small>لاعبين بالغرف</small><b>${rooms.reduce((s, r) => s + r.n, 0)}</b></div>
          <div class="tStat"><small>الوضع</small><b>أحمر ضد أزرق</b></div>`;
    }
}

/* ---------- النوافذ ---------- */
function modal(html) { $("#mBox").innerHTML = html; paintIcons($("#mBox")); $("#modal").classList.remove("hidden"); }
function closeModal() { $("#modal").classList.add("hidden"); view = null; }
$("#modal").addEventListener("mousedown", (e) => { if (e.target.id === "modal") closeModal(); });
$("#mBox").addEventListener("click", (e) => { if (e.target.closest("[data-x]")) closeModal(); });
function toast(t) { const el = document.createElement("div"); el.className = "toast"; el.textContent = t; $("#menu").appendChild(el); setTimeout(() => el.remove(), 2600); }
const head = (t) => `<div class="mHead"><h3>${t}</h3><button class="x" data-x>✕</button></div>`;

function carsModal() {
    const st = (s) => ({ 0: ["برا الكراج", "o"], 1: ["بالكراج", "g"], 2: ["بالحجز", "r"] }[s] || ["—", "o"]);
    const list = (D && D.vehicles) || [];
    modal(head("سياراتي") + `<div class="vList">${list.length ? list.map((v) => {
        const s = st(v.state);
        return `<div class="veh"><span class="ic sm" data-i="car"></span><div class="t"><b>${esc(v.label)}</b><small>${esc(v.garage || "")}</small></div><span class="st ${s[1]}">${s[0]}</span><span class="plate">${esc(v.plate)}</span></div>`;
    }).join("") : `<div class="empty">ما عندك سيارات بعد</div>`}</div>`);
}

function quitModal() {
    modal(head("تطلع من السيرفر؟") + `<p class="muted" style="font-size:1.7vh">شخصيتك تنحفظ وترجع بنفس المكان.</p>
      <div class="mFoot"><button class="btn" data-x>لا، أكمل</button><button class="btn danger" id="qYes">إي، اطلع</button></div>`);
    $("#qYes").onclick = () => post("quit");
}

/* ---------- تيد ام ---------- */
async function loadTdm() {
    TDM = (await post("tdmList")) || { rooms: [] };
    if (TDM.mine) ROOM = TDM.mine;
    renderTdmTile();
    return TDM;
}

async function tdmModal() {
    await loadTdm();
    if (ROOM) roomView(); else roomsView();
}

function roomsView() {
    view = "rooms";
    const rooms = (TDM && TDM.rooms) || [];
    modal(head("غرف التيد ام") + `<div class="rooms">${rooms.length ? rooms.map((r) => `
        <div class="room"><span class="ic sm" data-i="${r.locked ? "lock" : "users"}"></span>
          <div class="t"><b>${esc(r.name)}</b><small>المضيف: ${esc(r.host)}</small></div>
          <span class="tag ${r.state === "lobby" ? "wait" : "play"}">${r.state === "lobby" ? "بالانتظار" : "شغالة"}</span>
          <span class="n">${r.n}/${r.max}</span>
          <button class="btn" data-join="${r.id}" data-lock="${r.locked ? 1 : 0}" ${r.state !== "lobby" || r.n >= r.max ? "disabled" : ""}>دخول</button></div>`).join("")
        : `<div class="empty">ماكو غرف هسه — سوي وحدة وخلي ربعك يدخلون</div>`}</div>
      <div class="mFoot"><button class="btn" id="rRefresh">تحديث</button><button class="btn pri" id="rCreate">+ إنشاء غرفة</button></div>`);
    $("#rRefresh").onclick = async () => { await loadTdm(); roomsView(); };
    $("#rCreate").onclick = createView;
    $("#mBox").querySelectorAll("[data-join]").forEach((b) => (b.onclick = () => {
        if (b.dataset.lock === "1") return codeView(b.dataset.join);
        post("tdmJoin", { id: Number(b.dataset.join) });
    }));
}

function codeView(id) {
    view = "code";
    modal(head("الغرفة مقفولة") + `<div class="field"><label>اكتب كود الغرفة</label><input class="in" id="cCode" inputmode="numeric" maxlength="6" placeholder="1234" style="direction:ltr;text-align:center;letter-spacing:.6vh"></div>
      <div class="mFoot"><button class="btn" id="cBack">رجوع</button><button class="btn pri" id="cGo">دخول</button></div>`);
    setTimeout(() => $("#cCode").focus(), 50);
    $("#cBack").onclick = roomsView;
    $("#cGo").onclick = () => post("tdmJoin", { id: Number(id), code: $("#cCode").value.trim() });
}

function createView() {
    view = "create";
    const targets = (TDM && TDM.targets) || [20, 30, 50], times = (TDM && TDM.times) || [5, 10, 15];
    let target = targets[1], time = times[1];
    modal(head("غرفة جديدة") + `
      <div class="field"><label>اسم الغرفة</label><input class="in" id="nName" maxlength="24" placeholder="مثال: ربع OG"></div>
      <div class="field"><label>كود (اختياري — إذا حطيت كود، بس اللي يعرفه يدخل)</label><input class="in" id="nCode" inputmode="numeric" maxlength="6" placeholder="بدون كود = مفتوحة" style="direction:ltr;text-align:center;letter-spacing:.6vh"></div>
      <div class="field"><label>عدد القتلات للفوز</label><div class="chips" id="nT">${targets.map((t) => `<button class="chip${t === target ? " on" : ""}" data-v="${t}">${t}</button>`).join("")}</div></div>
      <div class="field"><label>مدة الجولة (دقيقة)</label><div class="chips" id="nM">${times.map((t) => `<button class="chip${t === time ? " on" : ""}" data-v="${t}">${t}</button>`).join("")}</div></div>
      <div class="mFoot"><button class="btn" id="nBack">رجوع</button><button class="btn pri" id="nGo">إنشاء</button></div>`);
    const pick = (box, set) => box.querySelectorAll(".chip").forEach((c) => (c.onclick = () => { box.querySelectorAll(".chip").forEach((x) => x.classList.toggle("on", x === c)); set(Number(c.dataset.v)); }));
    pick($("#nT"), (v) => (target = v)); pick($("#nM"), (v) => (time = v));
    setTimeout(() => $("#nName").focus(), 50);
    $("#nBack").onclick = roomsView;
    $("#nGo").onclick = () => post("tdmCreate", { name: $("#nName").value, code: $("#nCode").value.trim(), target, time });
}

function roomView() {
    view = "room";
    const r = ROOM;
    if (!r) return roomsView();
    const me = r.players.find((p) => p.id === ME) || {};
    const isHost = r.host === ME;
    const half = r.max / 2;
    const col = (t, label, c) => {
        const list = r.players.filter((p) => p.team === t);
        const slots = Array.from({ length: Math.max(0, half - list.length) }, () => `<li class="slot">مكان فاضي</li>`).join("");
        return `<div class="team" style="--tc:${c}"><h4>${label}<span>${list.length}/${half}</span></h4><ul>
          ${list.map((p) => `<li class="${p.id === ME ? "me" : ""}">${p.host ? `<span class="host">★</span>` : ""}${esc(p.name)}<span class="pv">${p.vote ? WLAB[p.vote] : "ما صوّت"}</span></li>`).join("")}${slots}</ul>
          ${me.team !== t && r.state === "lobby" ? `<button class="join" data-team="${t}">انتقل لهذا الفريق</button>` : ""}</div>`;
    };
    const totalVotes = Object.values(r.votes || {}).reduce((s, n) => s + n, 0) || 1;
    const canStart = r.players.some((p) => p.team === "red") && r.players.some((p) => p.team === "blue");
    modal(head(esc(r.name)) + `
      <div class="meta"><span class="tag">${r.locked ? "مقفولة بكود" : "مفتوحة"}</span><span class="tag">أول فريق يوصل ${r.target}</span><span class="tag">${r.time} دقايق</span>
        <span class="tag ${r.state === "lobby" ? "wait" : "play"}">${r.state === "lobby" ? "بالانتظار" : "الجولة شغالة"}</span></div>
      <div class="sec">الفرق</div>
      <div class="teams">${col("red", "الفريق الأحمر", "#ff4d6d")}${col("blue", "الفريق الأزرق", "#5aa2ff")}</div>
      <div class="sec">صوّت على السلاح (الأكثر أصوات يربح)</div>
      <div class="votes">${MODES.map((m) => {
        const n = (r.votes && r.votes[m.id]) || 0;
        return `<button class="vote${me.vote === m.id ? " on" : ""}" data-w="${m.id}" style="--m:${WCOL[m.id]}">${GUNS[m.id]}<b>${m.label}</b><small>${n} صوت</small><span class="bar"><i style="width:${(n / totalVotes) * 100}%"></i></span></button>`;
      }).join("")}</div>
      <div class="mFoot">
        <button class="btn danger" id="rLeave">اطلع من الغرفة</button>
        ${isHost && r.state === "lobby" ? `<div style="display:flex;gap:1vh"><button class="btn" id="rBal">رتب الفرق</button><button class="btn pri" id="rStart" ${canStart ? "" : "disabled"}>ابدأ الجولة</button></div>` : `<small class="muted">${r.state === "lobby" ? "ننطر المضيف يبدي الجولة" : "الجولة شغالة"}</small>`}
      </div>`);
    $("#mBox").querySelectorAll("[data-team]").forEach((b) => (b.onclick = () => post("tdmTeam", { team: b.dataset.team })));
    $("#mBox").querySelectorAll("[data-w]").forEach((b) => (b.onclick = () => r.state === "lobby" && post("tdmVote", { weapon: b.dataset.w })));
    $("#rLeave").onclick = () => post("tdmLeave");
    if ($("#rBal")) $("#rBal").onclick = () => post("tdmBalance");
    if ($("#rStart")) $("#rStart").onclick = () => post("tdmStart");
}

/* ---------- الأزرار ---------- */
document.querySelectorAll(".tile.click").forEach((t) => t.addEventListener("click", () => {
    const a = t.dataset.act;
    if (a === "map") post("map");
    else if (a === "settings") post("settings");
    else if (a === "cars") carsModal();
    else if (a === "tdm") tdmModal();
}));
$("#bResume").onclick = closeMenu;
$("#bQuit").onclick = quitModal;

function closeMenu() {
    const m = $("#menu");
    m.classList.add("out");
    setTimeout(() => { m.classList.add("hidden"); m.classList.remove("out"); }, 200);
    closeModal();
    post("close");
}
window.addEventListener("keydown", (e) => {
    if (e.key !== "Escape" || $("#menu").classList.contains("hidden")) return;
    if (!$("#modal").classList.contains("hidden")) closeModal(); else closeMenu();
});

window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    const parse = (v) => (typeof v === "string" ? JSON.parse(v) : v);
    if (m.me) ME = m.me;
    if (m.action === "open") {
        const d = parse(m.data);
        ME = d.id;
        render(d); closeModal();
        $("#menu").classList.remove("hidden", "out");
        loadTdm();
    } else if (m.action === "update") render(parse(m.data));
    else if (m.action === "close") { closeModal(); $("#menu").classList.add("hidden"); }
    else if (m.action === "room") {
        const was = ROOM;
        ROOM = m.room || null;
        renderTdmTile();
        if ($("#menu").classList.contains("hidden")) return;
        if (ROOM && (view === "rooms" || view === "create" || view === "code" || view === "room")) roomView();
        else if (!ROOM && was && view === "room") { loadTdm().then(roomsView); }
    }
});

/* ---------- معاينة خارج اللعبة ---------- */
let MOCK = () => null;
if (!IN_GAME) {
    document.body.style.background = "url(https://s.rsg.sc/sc/images/games/GTAV/map/render/4/3/5.jpg) center/cover, #2a3442";
    const rooms = [{ id: 1, name: "ربع OG", host: "حيدر", n: 5, max: 8, locked: false, state: "lobby" }, { id: 2, name: "VIP", host: "علي", n: 8, max: 8, locked: true, state: "playing" }];
    const room = { id: 3, name: "غرفة Stone", locked: true, host: 1, state: "lobby", target: 30, time: 10, max: 8,
        players: [{ id: 1, name: "Stone Ali", team: "red", host: true, vote: "ak" }, { id: 4, name: "حيدر كريم", team: "red", vote: "ak" }, { id: 7, name: "علي حسين", team: "blue", vote: "sniper" }],
        votes: { pistol: 0, ak: 2, sniper: 1, shotgun: 0 } };
    MOCK = (n, d) => {
        if (n === "tdmList") return { rooms, mine: false, targets: [20, 30, 50], times: [5, 10, 15] };
        if (n === "tdmCreate" || n === "tdmJoin") { setTimeout(() => window.postMessage({ action: "room", room, me: 1 }, "*"), 100); }
        if (n === "tdmLeave") { setTimeout(() => window.postMessage({ action: "room", room: false, me: 1 }, "*"), 100); }
        if (n === "tdmVote") { room.players[0].vote = d.weapon; setTimeout(() => window.postMessage({ action: "room", room, me: 1 }, "*"), 50); }
        return true;
    };
    window.postMessage({ action: "open", data: { title: "OG", subtitle: "ROLEPLAY", discord: "discord.gg/og", name: "Stone Ali", cid: "AYZ33545", id: 1, phone: "3255934386", birth: "1995-04-12",
        cash: 587, bank: 101545.59, job: "الأمن العام", grade: "لواء ركن", onduty: true, callsign: "101",
        arena: { counts: { pistol: 6, ak: 3, sniper: 1, shotgun: 4 }, inside: false }, online: 23, cops: 4, ems: 2, maxPlayers: 48,
        vehicles: [{ plate: "46EEK572", label: "Declasse Sultan", state: 1, garage: "pillboxgarage" }] } }, "*");
}
