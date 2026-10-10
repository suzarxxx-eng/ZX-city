const $ = (s) => document.querySelector(s);
const GUN = '<svg class="gun" viewBox="0 0 48 24"><path d="M2 6h34l4-3h6v6h-4v3H30l-3 4h-6l-2 6h-7l3-10H2z"/></svg>';
let me = 0;

function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }

function feed(d) {
    const f = el("div", "f");
    if (d.type === "kill") {
        if (d.kid === me || d.vid === me) f.classList.add("me");
        f.append(el("span", null, d.killer)); f.insertAdjacentHTML("beforeend", GUN); f.append(el("span", null, d.victim));
    } else if (d.type === "self") f.append(el("span", null, d.victim + " مات"));
    else if (d.type === "join") f.append(el("span", null, "➜ " + d.name + " دخل الأرينا"));
    else if (d.type === "leave") f.append(el("span", null, "← " + d.name + " طلع"));
    const box = $("#feed");
    box.prepend(f);
    while (box.children.length > 6) box.lastElementChild.remove();
    setTimeout(() => f.classList.add("out"), 6000);
    setTimeout(() => f.remove(), 6600);
}

function board(list) {
    const ol = $("#hBoard");
    ol.replaceChildren();
    $("#hCount").textContent = list.length + " لاعب";
    list.slice(0, 8).forEach((p, i) => {
        const li = el("li", p.id === me ? "me" : "");
        li.append(el("span", "p", i + 1), el("span", "n", p.name), el("span", "s", `${p.k} / ${p.d}`));
        ol.append(li);
        if (p.id === me) {
            $("#hK").textContent = p.k; $("#hD").textContent = p.d;
            $("#hR").textContent = (p.d ? p.k / p.d : p.k).toFixed(1);
        }
    });
}

window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    if (m.me) me = m.me;
    if (m.action === "enter") {
        const h = $("#hud");
        h.style.setProperty("--c", m.color || "#3ddc97");
        $("#hEn").textContent = m.en; $("#hLabel").textContent = "أرينا " + m.label; $("#hPlace").textContent = m.place || "";
        $("#hK").textContent = 0; $("#hD").textContent = 0; $("#hR").textContent = "0.0";
        $("#feed").replaceChildren();
        h.classList.remove("hidden");
    } else if (m.action === "exit") $("#hud").classList.add("hidden");
    else if (m.action === "feed") feed(m.d);
    else if (m.action === "board") board(m.list || []);
    else if (m.action === "oob") {
        $("#oob").classList.toggle("hidden", m.left < 0);
        $("#oobN").textContent = m.left;
    }
});

/* ===== تيد ام ===== */
let tdmTimer = null, tdmLeft = 0, myTeam = "red";
const TEAM = { red: "الأحمر", blue: "الأزرق" };
function fmt(s) { s = Math.max(0, s | 0); return String((s / 60) | 0).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0"); }
function tdmFeed(d) {
    const f = el("div", "f " + (d.kt || d.vt || ""));
    if ((d.kid && d.kid === me) || (d.vid && d.vid === me)) f.classList.add("me");
    if (d.type === "kill") {
        f.append(el("span", d.kt === "red" ? "kr" : "kb", d.killer));
        f.insertAdjacentHTML("beforeend", GUN);
        f.append(el("span", d.vt === "red" ? "kr" : "kb", d.victim));
    } else if (d.type === "self") f.append(el("span", null, d.victim + " مات"));
    else if (d.type === "join") f.append(el("span", null, "➜ " + d.name + " دخل الغرفة"));
    else if (d.type === "leave") f.append(el("span", null, "← " + d.name + " طلع"));
    else if (d.type === "host") f.append(el("span", null, "★ " + d.name + " صار المضيف"));
    const box = $("#tFeed");
    box.prepend(f);
    while (box.children.length > 6) box.lastElementChild.remove();
    setTimeout(() => f.classList.add("out"), 6000);
    setTimeout(() => f.remove(), 6600);
}
function tdmScore(s) { $("#sRed").textContent = s.red; $("#sBlue").textContent = s.blue; }
window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    if (m.me) me = m.me;
    if (m.action === "tdmStart") {
        myTeam = m.team;
        $("#tdm").classList.remove("hidden");
        $("#result").classList.add("hidden");
        $("#tFeed").replaceChildren();
        tdmScore({ red: 0, blue: 0 });
        $("#tGoal").textContent = "أول فريق يوصل " + m.target;
        const mt = $("#myTeam");
        mt.className = "myTeam " + m.team;
        mt.textContent = "فريقك: " + TEAM[m.team] + " • " + m.weapon;
        tdmLeft = m.seconds;
        $("#tTimer").textContent = fmt(tdmLeft);
        clearInterval(tdmTimer);
        tdmTimer = setInterval(() => { tdmLeft--; $("#tTimer").textContent = fmt(tdmLeft); }, 1000);
    } else if (m.action === "tdmScore") tdmScore(m.score);
    else if (m.action === "tdmFeed") tdmFeed(m.d);
    else if (m.action === "tdmEnd") {
        clearInterval(tdmTimer);
        const d = m.d, r = $("#result");
        tdmScore(d.score);
        r.className = "result " + (d.winner === "draw" ? "" : d.winner === myTeam ? "win" : "lose");
        $("#rTitle").textContent = d.winner === "draw" ? "تعادل" : (d.winner === myTeam ? "فزتوا! " : "خسرتوا — ") + "الفريق " + TEAM[d.winner] + (d.winner === myTeam ? "" : " فاز");
        $("#rRed").textContent = d.score.red; $("#rBlue").textContent = d.score.blue;
        $("#rMvp").textContent = d.mvp ? "★ أحسن لاعب: " + d.mvp : "";
        const players = (d.view && d.view.players) || [];
        for (const t of ["red", "blue"]) {
            const ol = $(t === "red" ? "#rRedList" : "#rBlueList");
            ol.replaceChildren();
            players.filter((p) => p.team === t).sort((a, b) => b.k - a.k).forEach((p) => {
                const li = el("li", p.id === me ? "me" : "");
                li.append(el("b", null, p.name), el("span", null, p.k + " / " + p.d));
                ol.append(li);
            });
        }
        r.classList.remove("hidden");
    } else if (m.action === "tdmExit") {
        clearInterval(tdmTimer);
        $("#tdm").classList.add("hidden");
    }
});
