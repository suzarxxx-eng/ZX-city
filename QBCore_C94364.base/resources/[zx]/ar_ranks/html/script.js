/* لوحة رتب الأمن العام */
const $ = (s) => document.querySelector(s);
const IN_GAME = typeof GetParentResourceName === "function";
const RES = IN_GAME ? GetParentResourceName() : "ar_ranks";
const post = (n, d = {}) =>
    fetch(`https://${RES}/${n}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(d) })
        .then((r) => r.json()).catch(() => null);

let D = null;            // البيانات من السيرفر
let selRank = null;      // فلتر الرتبة
let filter = "all";      // الكل / متصل / بالدوام
let busy = false;

/* ---------- رسم الشارات ---------- */
const GOLD = "#f5c451";
function star(x) {
    const pts = [];
    for (let i = 0; i < 10; i++) {
        const r = i % 2 ? 2.6 : 6, a = Math.PI / 5 * i - Math.PI / 2;
        pts.push((x + 7 + r * Math.cos(a)).toFixed(2) + "," + (12 + r * Math.sin(a)).toFixed(2));
    }
    return `<polygon points="${pts.join(" ")}" fill="${GOLD}"/>`;
}
function eagle(x) {
    return `<g transform="translate(${x},0)" fill="${GOLD}">
      <path d="M11 4c1.2 0 2 .9 2 2l-.6 1.2L19 5l-2.2 4.2L21 9l-4 2.6 1.5 1.4-4.5.4L12 18l-1-1-1 1-2-4.6-4.5-.4L5 11.6 1 9l4.2.2L3 5l6.6 2.2L9 6c0-1.1.8-2 2-2z"/>
      <rect x="9" y="18.5" width="4" height="2" rx=".6"/></g>`;
}
function swords(x) {
    return `<g transform="translate(${x},0)" stroke="${GOLD}" stroke-width="1.8" stroke-linecap="round">
      <line x1="3" y1="20" x2="19" y2="4"/><line x1="19" y1="20" x2="3" y2="4"/>
      <line x1="2" y1="16" x2="7" y2="21"/><line x1="20" y1="16" x2="15" y2="21"/></g>`;
}
function chevrons(x, n, bar) {
    let s = `<g transform="translate(${x},0)" fill="none" stroke="${GOLD}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round">`;
    const top = 12 - (n - 1) * 2.6 - (bar ? 2 : 0);
    for (let i = 0; i < n; i++) {
        const y = top + i * 5.2;
        s += `<polyline points="2,${y + 5} 9,${y} 16,${y + 5}"/>`;
    }
    if (bar) s += `<line x1="3" y1="${top + n * 5.2 + 3}" x2="15" y2="${top + n * 5.2 + 3}"/>`;
    return s + "</g>";
}
function insignia(ins) {
    ins = ins || {};
    let x = 3, body = "";
    if (ins.chev) { body += chevrons(x, ins.chev, ins.bar); x += 18; }
    if (ins.swords) { body += swords(x); x += 23; }
    if (ins.eagle) { body += eagle(x); x += 23; }
    for (let i = 0; i < (ins.stars || 0); i++) { body += star(x); x += 14; }
    if (!body) return `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" fill="none" stroke="#5c6b80" stroke-width="1.6"/></svg>`;
    const w = x + 3;
    const bg = ins.red
        ? `<rect x="0" y="1" width="${w}" height="22" rx="4" fill="#b3132f"/><rect x="0" y="1" width="${w}" height="22" rx="4" fill="none" stroke="${GOLD}" stroke-width=".8"/>`
        : "";
    return `<svg viewBox="0 0 ${w} 24" style="width:${w * (22 / 24)}px">${bg}${body}</svg>`;
}
const insOf = (lvl) => (D && D.insignia ? D.insignia[String(lvl)] : null);

/* ---------- رسالة ---------- */
let toastT;
function toast(msg, ok) {
    const t = $("#toast");
    t.textContent = msg;
    t.className = ok ? "ok" : "err";
    clearTimeout(toastT);
    toastT = setTimeout(() => t.classList.add("hidden"), 2800);
}

/* ---------- الرسم ---------- */
const gradeName = (lvl) => (D.grades.find((g) => g.level === lvl) || {}).name || ("رتبة " + lvl);

function renderHeader() {
    $("#jobName").textContent = D.job;
    $("#meRank").textContent = D.me.rank;
    $("#meName").textContent = D.me.name;
    $("#meIns").innerHTML = insignia(insOf(D.me.level));
    $("#hireBox").classList.toggle("hidden", !D.perms.hire);
}

function renderLadder() {
    const box = $("#ladder");
    box.replaceChildren();
    const groups = D.groups && D.groups.length ? D.groups : [{ from: 0, to: 999, label: "الرتب" }];
    const desc = [...D.grades].sort((a, b) => b.level - a.level);
    [...groups].reverse().forEach((gr) => {
        const items = desc.filter((g) => g.level >= gr.from && g.level <= gr.to);
        if (!items.length) return;
        const h = document.createElement("div");
        h.className = "grp";
        h.textContent = gr.label;
        box.appendChild(h);
        items.forEach((g) => {
            const el = document.createElement("div");
            el.className = "rank" + (g.level === selRank ? " sel" : "") + (g.level === D.me.level ? " mine" : "");
            el.innerHTML = `<span class="lv">${g.level}</span><span class="ins"></span><span class="rn"></span>${g.isboss ? '<span class="boss">★ قيادة</span>' : ""}<span class="ct${g.count ? " has" : ""}">${g.count}</span>`;
            el.querySelector(".ins").innerHTML = insignia(insOf(g.level));
            el.querySelector(".rn").textContent = g.name;
            el.onclick = () => { selRank = selRank === g.level ? null : g.level; renderAll(); };
            box.appendChild(el);
        });
    });
    $("#allBtn").classList.toggle("on", selRank === null);
}

// الرتب اللي يكدر المسؤول يحطها
function allowedLevels(targetLevel) {
    const p = D.perms;
    if (!p.manage || targetLevel >= p.level) return [];
    const max = p.level >= p.top ? p.top : p.level - 1;
    return D.grades.filter((g) => g.level <= max).map((g) => g.level);
}

function renderMembers() {
    const q = $("#search").value.trim().toLowerCase();
    const all = D.members;
    $("#cAll").textContent = all.length;
    $("#cOn").textContent = all.filter((m) => m.online).length;
    $("#cDuty").textContent = all.filter((m) => m.onduty).length;

    const list = all.filter((m) => {
        if (selRank !== null && m.level !== selRank) return false;
        if (filter === "online" && !m.online) return false;
        if (filter === "duty" && !m.onduty) return false;
        if (q && !(m.name.toLowerCase().includes(q) || String(m.callsign || "").toLowerCase().includes(q) || String(m.id || "") === q)) return false;
        return true;
    });

    const ul = $("#members");
    ul.replaceChildren();
    if (!list.length) {
        const li = document.createElement("li");
        li.className = "empty";
        li.textContent = "ماكو منتسبين بهذا البحث";
        ul.appendChild(li);
        return;
    }

    list.forEach((m) => {
        const li = document.createElement("li");
        li.className = (m.online ? "online " : "") + (m.onduty ? "duty " : "") + (m.me ? "me" : "");

        const dot = document.createElement("i");
        dot.className = "dot";

        const who = document.createElement("div");
        who.className = "who";
        const nb = document.createElement("b");
        nb.textContent = m.name + (m.me ? "  (أنت)" : "");
        const st = document.createElement("small");
        st.textContent = m.onduty ? "بالدوام" + (m.id ? " • ID " + m.id : "") : m.online ? "متصل - مو بالدوام" + (m.id ? " • ID " + m.id : "") : "غير متصل";
        who.append(nb, st);

        const cs = document.createElement("span");
        cs.className = "cs" + (m.callsign ? "" : " none");
        cs.textContent = m.callsign || "—";

        const rk = document.createElement("span");
        rk.className = "rk";
        rk.innerHTML = `<span class="ins">${insignia(insOf(m.level))}</span>`;
        rk.append(document.createTextNode(m.rank));

        li.append(dot, who, cs, rk);

        const levels = allowedLevels(m.level);
        if (levels.length || (D.perms.hire && m.level < D.perms.level)) {
            const ctl = document.createElement("div");
            ctl.className = "ctl";
            if (levels.length) {
                const higher = levels.filter((l) => l > m.level);
                const lower = levels.filter((l) => l < m.level);
                const up = document.createElement("button");
                up.className = "up"; up.textContent = "▲"; up.title = "ترقية";
                up.disabled = !higher.length;
                up.onclick = () => act({ type: "grade", cid: m.cid, level: Math.min(...higher) });
                const dn = document.createElement("button");
                dn.className = "down"; dn.textContent = "▼"; dn.title = "تنزيل";
                dn.disabled = !lower.length;
                dn.onclick = () => act({ type: "grade", cid: m.cid, level: Math.max(...lower) });
                const sel = document.createElement("select");
                sel.title = "تحديد الرتبة";
                [...new Set([...levels, m.level])].sort((a, b) => b - a).forEach((l) => {
                    const o = document.createElement("option");
                    o.value = l; o.textContent = gradeName(l); o.selected = l === m.level;
                    sel.appendChild(o);
                });
                sel.onchange = () => act({ type: "grade", cid: m.cid, level: Number(sel.value) });
                ctl.append(up, dn, sel);
            }
            if (D.perms.hire && m.level < D.perms.level) {
                const f = document.createElement("button");
                f.className = "fire"; f.textContent = "فصل";
                f.onclick = () => {
                    if (!f.classList.contains("arm")) {
                        f.classList.add("arm"); f.textContent = "تأكيد؟";
                        setTimeout(() => { f.classList.remove("arm"); f.textContent = "فصل"; }, 3000);
                        return;
                    }
                    act({ type: "fire", cid: m.cid });
                };
                ctl.appendChild(f);
            }
            li.appendChild(ctl);
        }
        ul.appendChild(li);
    });
}

function renderAll() {
    if (!D) return;
    renderHeader();
    renderLadder();
    renderMembers();
}

/* ---------- الأوامر ---------- */
async function act(a) {
    if (busy) return;
    busy = true;
    const res = IN_GAME ? await post("action", a) : demoAction(a);
    busy = false;
    if (!res) return toast("صار خطأ", false);
    if (res.data) { D = res.data; renderAll(); }
    if (res.msg) toast(res.msg, res.ok);
}

function closePanel() {
    $("#panel").classList.add("hidden");
    if (IN_GAME) post("close");
}

$("#closeBtn").onclick = closePanel;
$("#allBtn").onclick = () => { selRank = null; renderAll(); };
$("#search").oninput = renderMembers;
document.querySelectorAll(".seg button").forEach((b) => {
    b.onclick = () => {
        filter = b.dataset.f;
        document.querySelectorAll(".seg button").forEach((x) => x.classList.toggle("on", x === b));
        renderMembers();
    };
});
$("#hireBtn").onclick = () => {
    const id = Number($("#hireId").value);
    if (!id) return toast("اكتب رقم اللاعب", false);
    act({ type: "hire", id });
    $("#hireId").value = "";
};
window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("#panel").classList.contains("hidden")) closePanel();
});

/* ---------- إشعار الترقية ---------- */
let popT;
function showChanged(d) {
    const p = $("#popup");
    p.classList.remove("hidden", "out", "down");
    if (!d.up) p.classList.add("down");
    $("#pIns").innerHTML = `<span class="ins big">${insignia(d.insignia)}</span>`;
    $("#pHead").textContent = d.hired ? "أهلاً بيك بالأمن العام" : d.up ? "مبروك! تمت ترقيتك إلى رتبة" : "تم تنزيل رتبتك إلى";
    $("#pRank").textContent = d.rank;
    $("#pBy").textContent = d.by ? "بأمر: " + d.by : "";
    clearTimeout(popT);
    popT = setTimeout(() => {
        p.classList.add("out");
        setTimeout(() => p.classList.add("hidden"), 500);
    }, 6000);
}

window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    if (m.action === "open") {
        D = m.data;
        selRank = null;
        $("#search").value = "";
        $("#panel").classList.remove("hidden");
        renderAll();
    } else if (m.action === "close") {
        $("#panel").classList.add("hidden");
    } else if (m.action === "changed") {
        showChanged(m.data);
    }
});

/* ---------- معاينة خارج اللعبة ---------- */
function demoAction(a) {
    const m = D.members.find((x) => x.cid === a.cid);
    if (a.type === "grade" && m) {
        const up = a.level > m.level;
        D.grades.find((g) => g.level === m.level).count--;
        m.level = a.level; m.rank = gradeName(a.level);
        D.grades.find((g) => g.level === m.level).count++;
        if (up) showChanged({ up, rank: m.rank, insignia: insOf(m.level), by: D.me.rank + " " + D.me.name });
        return { ok: true, msg: (up ? "تمت ترقية " : "تم تنزيل ") + m.name + " إلى " + m.rank, data: D };
    }
    if (a.type === "fire" && m) {
        D.members = D.members.filter((x) => x !== m);
        D.grades.find((g) => g.level === m.level).count--;
        return { ok: true, msg: "تم فصل " + m.name, data: D };
    }
    return { ok: false, msg: "ماكو لاعب متصل بهذا الرقم" };
}

if (!IN_GAME) {
    const names = ["مستجد", "شرطي", "شرطي أول", "عريف", "نائب ضابط", "ملازم", "ملازم أول", "نقيب", "رائد", "مقدم", "عقيد", "عميد", "لواء", "لواء ركن"];
    const ins = { 0: {}, 1: { chev: 1 }, 2: { chev: 2 }, 3: { chev: 3 }, 4: { chev: 3, bar: true }, 5: { stars: 1 }, 6: { stars: 2 }, 7: { stars: 3 }, 8: { eagle: true }, 9: { eagle: true, stars: 1 }, 10: { eagle: true, stars: 2 }, 11: { eagle: true, stars: 3 }, 12: { swords: true, eagle: true, stars: 1 }, 13: { swords: true, eagle: true, stars: 1, red: true } };
    const people = [["Stone Ali", 13, "101", 1, 1], ["حيدر كريم", 10, "205", 2, 1], ["علي حسين", 7, "312", 3, 0], ["مصطفى جبار", 5, null, 0, 0], ["أحمد ستار", 3, "450", 5, 1], ["عباس فاضل", 1, null, 0, 0], ["محمد رعد", 0, null, 7, 0]];
    D = {
        job: "الأمن العام",
        me: { level: 13, rank: "لواء ركن", name: "Stone Ali" },
        perms: { manage: true, hire: true, top: 13, level: 13 },
        grades: names.map((n, i) => ({ level: i, name: n, isboss: i >= 12, count: people.filter((p) => p[1] === i).length })),
        members: people.map((p, i) => ({ cid: "C" + i, name: p[0], level: p[1], rank: names[p[1]], callsign: p[2], id: p[3] || null, online: !!p[3], onduty: !!p[4], me: i === 0 })),
        insignia: ins,
        groups: [{ from: 0, to: 4, label: "المراتب" }, { from: 5, to: 10, label: "الضباط" }, { from: 11, to: 99, label: "القادة" }],
    };
    document.body.style.background = "#1b2735";
    $("#panel").classList.remove("hidden");
    renderAll();
}
