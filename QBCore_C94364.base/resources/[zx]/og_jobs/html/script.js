const RES = typeof GetParentResourceName === "function" ? GetParentResourceName() : "og_jobs";
const $ = (s) => document.querySelector(s);

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
    }).then((r) => r.text()).then((t) => { try { return JSON.parse(t); } catch (e) { return t; } }).catch(() => null);
}

const S = { open: false, tab: "requests", data: null, timer: null };
const TITLES = { requests: "طلبات الزبائن", progress: "تقدمي", cars: "السيارات", board: "المتصدرين" };

function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
}

function renderHeader() {
    const d = S.data;
    $("#title").textContent = TITLES[S.tab];
    const next = d.nextXp ? ` / ${d.nextXp}` : " (أعلى مستوى)";
    $("#lvlTxt").textContent = `المستوى ${d.level} • ${d.xp}${next} خبرة`;
    const prev = d.level > 1 ? levelStart(d) : 0;
    const pct = d.nextXp ? Math.min(100, ((d.xp - prev) / (d.nextXp - prev)) * 100) : 100;
    $("#xpBar").style.width = pct + "%";
}

function levelStart(d) {
    // بداية المستوى الحالي (نخزنها من السيرفر بالـ levels)
    return (d.levels && d.levels[d.level - 1]) || 0;
}

function distText(m) {
    return m >= 1000 ? (m / 1000).toFixed(1) + " كم" : m + " م";
}

// ---------------------------------------------------------------- طلبات الزبائن (لاعبين)
function renderActive(view, a) {
    const card = el("div", "card vip");
    card.appendChild(el("div", "ic", a.state === "riding" ? "🚖" : "📍"));
    const info = el("div", "info");
    const b = el("b", "", a.name);
    if (a.vip) b.appendChild(el("span", "badge", "VIP"));
    info.appendChild(b);
    info.appendChild(el("small", "", a.state === "riding"
        ? `المشوار شغال • ${distText(a.dist || 0)} • الأجرة $${a.fare || 0}`
        : "بالطريق للزبون • أول ما يركب العداد يشتغل"));
    card.appendChild(info);
    if (a.state === "riding") {
        const end = el("button", "btn", "إنهاء");
        end.addEventListener("click", () => { post("endRide"); closeTablet(); });
        card.appendChild(end);
    }
    const cancel = el("button", "btn ghost", "إلغاء");
    cancel.addEventListener("click", () => { post("cancelRide"); closeTablet(); });
    card.appendChild(cancel);
    view.appendChild(card);
}

function renderRequests(view) {
    const d = S.data;
    if (d.active) renderActive(view, d.active);
    const list = d.requests || [];
    if (!list.length) {
        const empty = el("div", "empty", d.active ? "" : "ماكو طلبات هسه. الطلبات تظهر هنا لمن اللاعبين يكتبون /taxi");
        return view.appendChild(empty);
    }
    list.forEach((r) => {
        const card = el("div", "card" + (r.vip ? " vip" : "") + (r.locked ? " locked" : ""));
        card.appendChild(el("div", "ic", r.locked ? "🔒" : r.vip ? "👑" : "👤"));
        const info = el("div", "info");
        const b = el("b", "", r.name);
        if (r.vip) b.appendChild(el("span", "badge", "VIP"));
        info.appendChild(b);
        const bits = [`يبعد ${distText(r.dist)}`];
        if (r.destDist) bits.push(`الوجهة ${distText(r.destDist)}`);
        if (r.fare) bits.push(`أجرة تقريبية $${r.fare}`);
        if (!r.destDist) bits.push("بدون وجهة محددة");
        info.appendChild(el("small", "", r.locked ? `يفتح عند المستوى ${r.minLevel}` : bits.join(" • ")));
        card.appendChild(info);
        const btn = el("button", "btn", "قبول");
        btn.disabled = r.locked || !!d.active;
        btn.title = d.active ? "عندك مشوار شغال" : "";
        btn.addEventListener("click", () => { post("accept", { id: r.id }); closeTablet(); });
        card.appendChild(btn);
        view.appendChild(card);
    });
}

function renderProgress(view) {
    const d = S.data;
    const grid = el("div", "stats");
    [["المستوى", d.level], ["الخبرة", d.xp], ["عدد المشاوير", d.trips], ["الدخل الكلي", "$" + d.earned]].forEach(([label, val]) => {
        const s = el("div", "stat");
        s.appendChild(el("b", "", String(val)));
        s.appendChild(el("span", "", label));
        grid.appendChild(s);
    });
    view.appendChild(grid);
}

function renderCars(view) {
    S.data.vehicles.forEach((v) => {
        const card = el("div", "card" + (v.locked ? " locked" : "") + (v.vip ? " vip" : ""));
        card.appendChild(el("div", "ic", v.locked ? "🔒" : "🚕"));
        const info = el("div", "info");
        const b = el("b", "", v.label);
        if (v.vip) b.appendChild(el("span", "badge", "VIP"));
        info.appendChild(b);
        info.appendChild(el("small", "", v.locked ? `يفتح عند المستوى ${v.minLevel}` : "متاحة لك"));
        card.appendChild(info);
        const btn = el("button", "btn", "استلام");
        btn.disabled = v.locked;
        btn.addEventListener("click", () => { post("vehicle", { id: v.id }); closeTablet(); });
        card.appendChild(btn);
        view.appendChild(card);
    });
}

function renderBoard(view) {
    const b = S.data.board;
    if (!b.length) return view.appendChild(el("div", "empty", "ماكو متصدرين للحين، كن أول واحد!"));
    b.forEach((r, i) => {
        const row = el("div", "row");
        row.appendChild(el("div", "rank", String(i + 1)));
        row.appendChild(el("div", "nm", r.name || "—"));
        row.appendChild(el("div", "v", `${r.trips} مشوار • $${r.earned}`));
        view.appendChild(row);
    });
}

function render() {
    if (!S.data) return;
    renderHeader();
    const view = $("#view");
    view.replaceChildren();
    ({ requests: renderRequests, progress: renderProgress, cars: renderCars, board: renderBoard })[S.tab](view);
    document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("on", t.dataset.tab === S.tab));
}

// الطلبات تتحدث لحالها وانت فاتح التابلت (اللاعبين يطلبون ويلغون طول الوقت)
async function refresh() {
    if (!S.open) return;
    const fresh = await post("taxiRefresh");
    if (S.open && fresh && fresh.requests) {
        S.data = fresh;
        render();
    }
}

function openTablet(data) {
    S.open = true;
    S.data = data;
    S.tab = "requests";
    $("#stage").classList.remove("hidden");
    render();
    clearInterval(S.timer);
    S.timer = setInterval(refresh, 4000);
}

function closeTablet() {
    if (!S.open) return;
    S.open = false;
    clearInterval(S.timer);
    $("#stage").classList.add("hidden");
    post("close");
}

function meter(d) {
    const m = $("#meter");
    if (!d.show) return m.classList.add("hidden");
    m.classList.remove("hidden");
    $("#mFare").textContent = Math.floor(d.fare);
    $("#mDist").textContent = (d.dist / 1000).toFixed(1) + " كم";
}

document.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", () => { S.tab = t.dataset.tab; render(); }));
$("#closeBtn").addEventListener("click", closeTablet);
window.addEventListener("keydown", (e) => { if (e.key === "Escape") closeTablet(); });
window.addEventListener("message", ({ data }) => {
    if (!data || !data.action) return;
    if (data.action === "open") openTablet(data.data);
    else if (data.action === "close") closeTablet();
    else if (data.action === "meter") meter(data);
});
