/* إشعارات بلاغات الأمن العام */
const stack = document.getElementById("stack");
const MAX = 4;
const cards = new Map(); // id -> element

const ICON = {
    pin: "M12 2a7 7 0 0 0-7 7c0 5.3 7 13 7 13s7-7.7 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5z",
    dist: "M12 2 4.5 20.3l.7.7L12 18l6.8 3 .7-.7z",
    user: "M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-5.3 0-10 2.7-10 6v2h20v-2c0-3.3-4.7-6-10-6z",
    car: "M18.9 6c-.2-.6-.8-1-1.4-1h-11c-.7 0-1.2.4-1.4 1L3 12v8c0 .6.4 1 1 1h1c.6 0 1-.4 1-1v-1h12v1c0 .6.4 1 1 1h1c.6 0 1-.4 1-1v-8zM6.5 16a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm11 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zM5 11l1.5-4.5h11L19 11z",
};

function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
}
function line(icon, ...parts) {
    const l = el("div", "ln");
    l.innerHTML = `<svg viewBox="0 0 24 24"><path d="${ICON[icon]}"/></svg>`;
    parts.forEach((p) => l.append(p));
    return l;
}
const fmtDist = (m) => (m >= 1000 ? (m / 1000).toFixed(1) + " كم" : m + " م");

function showAlert(a, showTime, key) {
    const c = el("div", "al" + (a.priority >= 3 ? " p3" : ""));
    c.style.setProperty("--c", a.color || "#2f8cff");

    const hd = el("div", "hd");
    hd.append(el("span", "code", a.code), el("span", "ttl", a.title), el("span", "id", "#" + a.id));
    c.append(hd);

    const bd = el("div", "bd");
    bd.append(line("pin", el("b", null, a.street || "شارع غير معروف"), el("span", "mu", a.zone ? "• " + a.zone : "")));
    if (a.dist !== undefined) bd.append(line("dist", el("span", "mu", "يبعد عنك"), el("b", null, fmtDist(a.dist))));
    if (a.message) bd.append(el("div", "msg", a.message));

    const chips = el("div", "chips");
    if (a.gender) chips.append(el("span", "chip", "المشتبه: " + a.gender));
    (a.details || []).forEach((d) => chips.append(el("span", "chip", d[0] + ": " + d[1])));
    if (a.vehicle) {
        if (a.vehicle.model) chips.append(el("span", "chip", "🚗 " + a.vehicle.model));
        if (a.vehicle.plate) chips.append(el("span", "chip pl", a.vehicle.plate));
    }
    if (chips.children.length) bd.append(chips);
    c.append(bd);

    const ft = el("div", "ft");
    ft.append(el("span", "key", key || "G"), el("span", null, "تحديد الموقع والاستجابة"));
    const rs = el("span", "rs", "");
    ft.append(rs);
    c.append(ft);
    c._rs = rs;
    setResponders(c, a.responders);

    const bar = el("div", "bar");
    bar.style.animationDuration = showTime + "ms";
    c.append(bar);

    stack.prepend(c);
    cards.set(a.id, c);
    while (stack.children.length > MAX) removeCard(stack.lastElementChild);
    c._timer = setTimeout(() => removeCard(c), showTime);
}

function setResponders(c, list) {
    const n = (list || []).length;
    c._rs.textContent = n ? `مستجيبين: ${n}` : "";
    c.title = (list || []).join("\n");
}

function removeCard(c) {
    if (!c || c._gone) return;
    c._gone = true;
    clearTimeout(c._timer);
    for (const [k, v] of cards) if (v === c) cards.delete(k);
    c.classList.add("out");
    setTimeout(() => c.remove(), 400);
}

window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    if (m.action === "alert") showAlert(m.alert, m.showTime || 9000, m.key);
    else if (m.action === "update") { const c = cards.get(m.id); if (c) setResponders(c, m.responders); }
    else if (m.action === "responding") { const c = cards.get(m.id); if (c) { c.classList.add("resp"); clearTimeout(c._timer); c._timer = setTimeout(() => removeCard(c), 2500); } }
    else if (m.action === "clear") [...stack.children].forEach(removeCard);
});

/* معاينة خارج اللعبة */
if (typeof GetParentResourceName !== "function") {
    document.body.style.background = "#3a4a5e";
    const demo = [
        { id: 12, code: "10-71", title: "إطلاق نار", color: "#ff4d6d", priority: 2, street: "Grove St / Davis Ave", zone: "Davis", dist: 820, gender: "ذكر", details: [["من داخل", "مركبة"]], vehicle: { model: "Sultan", plate: "46EEK572" }, responders: [] },
        { id: 13, code: "10-90", title: "سرقة بنك", color: "#ff2e57", priority: 3, street: "Hawick Ave", zone: "Hawick", dist: 2450, responders: ["[101] لواء ركن Stone"] },
        { id: 14, code: "10-37", title: "حركة مشبوهة", color: "#f5c451", priority: 1, street: "Vespucci Blvd", zone: "Little Seoul", dist: 300, message: "شخص يوجه سلاح على مواطن", gender: "أنثى", responders: [] },
    ];
    demo.forEach((a, i) => setTimeout(() => showAlert(a, 60000, "G"), i * 300));
}
