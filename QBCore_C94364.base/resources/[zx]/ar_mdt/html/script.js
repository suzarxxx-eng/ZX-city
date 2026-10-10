/* =========================================================
   MDT الأمن العام
   ========================================================= */
const IN_GAME = typeof GetParentResourceName === "function";
const RES = IN_GAME ? GetParentResourceName() : "ar_mdt";
const $ = (s, r = document) => r.querySelector(s);

let ME = {}, CFG = {}, PAGE = "dash", COUNTS = {};

/* ---------- أدوات ---------- */
function h(tag, props, ...kids) {
    const el = document.createElement(tag);
    if (props) for (const [k, v] of Object.entries(props)) {
        if (v === undefined || v === null || v === false) continue;
        if (k === "class") el.className = v;
        else if (k === "style") el.style.cssText = v;
        else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
        else if (k === "html") el.innerHTML = v; // بس للأيقونات الثابتة
        else if (k === "value") el.value = v;
        else if (k === "checked") el.checked = v;
        else el.setAttribute(k, v === true ? "" : v);
    }
    for (const c of kids.flat(Infinity)) {
        if (c === null || c === undefined || c === false) continue;
        el.append(c instanceof Node ? c : document.createTextNode(String(c)));
    }
    return el;
}

const P = {
    dash: "M3 13h8V3H3zm0 8h8v-6H3zm10 0h8V11h-8zm0-18v6h8V3z",
    user: "M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-5.3 0-10 2.7-10 6v2h20v-2c0-3.3-4.7-6-10-6z",
    car: "M18.9 6c-.2-.6-.8-1-1.4-1h-11c-.7 0-1.2.4-1.4 1L3 12v8c0 .6.4 1 1 1h1c.6 0 1-.4 1-1v-1h12v1c0 .6.4 1 1 1h1c.6 0 1-.4 1-1v-8zM6.5 16a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm11 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zM5 11l1.5-4.5h11L19 11z",
    report: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zm2 16H8v-2h8zm0-4H8v-2h8zm-3-5V3.5L18.5 9z",
    warrant: "M12 2 1 21h22zm1 16h-2v-2h2zm0-4h-2V9h2z",
    bolo: "M18 11v2h4v-2zm-2 6.6 3.2 2.4 1.2-1.6-3.2-2.4zM20.4 5.6 19.2 4 16 6.4l1.2 1.6zM4 9a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h1v4h2v-4h1l5 3V6L8 9zm11.5 3c0-1.3-.6-2.5-1.5-3.4v6.7c.9-.8 1.5-2 1.5-3.3z",
    law: "M12 2 2 7v2h20V7zM4 11v7h3v-7zm6.5 0v7h3v-7zM17 11v7h3v-7zM2 20v2h20v-2z",
    units: "M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm-8 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-2.3 0-7 1.2-7 3.5V19h14v-2.5C15 14.2 10.3 13 8 13zm8 0h-1c1.2.8 2 2 2 3.5V19h6v-2.5c0-2.3-4.7-3.5-7-3.5z",
    search: "M15.5 14h-.8l-.3-.3A6.5 6.5 0 1 0 14 15.5l.3.3v.8l5 5 1.5-1.5zm-6 0a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9z",
    plus: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6z",
    siren: "M11 2h2v3h-2zM4.2 5.6l1.4-1.4 2.1 2.1-1.4 1.4zm13.5.7 2.1-2.1 1.4 1.4-2.1 2.1zM12 7a6 6 0 0 0-6 6v5h12v-5a6 6 0 0 0-6-6zm-1 3.2V15H9.5v-3.2zM4 19h16v3H4z",
    pin: "M12 2a7 7 0 0 0-7 7c0 5.3 7 13 7 13s7-7.7 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5z",
    gavel: "m1 21h12v2H1zM5.2 8.2l2.8-2.8 14.1 14.1-2.8 2.8zM12.3 1.1l5.6 5.6-2.8 2.8-5.6-5.6zM3.8 9.6l5.6 5.6-2.8 2.8L1 12.4z",
};
const icon = (n) => h("span", { html: `<svg viewBox="0 0 24 24"><path d="${P[n]}"/></svg>`, style: "display:contents" });

const money = (n) => "$" + Math.round(Number(n) || 0).toLocaleString("en-US");
function ago(ts) {
    if (!ts) return "";
    const s = Math.floor(Date.now() / 1000 - ts);
    if (s < 60) return "هسه";
    if (s < 3600) return "قبل " + Math.floor(s / 60) + " د";
    if (s < 86400) return "قبل " + Math.floor(s / 3600) + " س";
    const d = new Date(ts * 1000);
    return d.toLocaleDateString("en-GB") + " " + d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
}
const fullDate = (ts) => ts ? new Date(ts * 1000).toLocaleString("en-GB", { dateStyle: "short", timeStyle: "short" }) : "";
const parse = (v) => { if (Array.isArray(v)) return v; try { return JSON.parse(v) || []; } catch (e) { return []; } };
const gender = (g) => (Number(g) === 1 ? "أنثى" : "ذكر");
const vState = (s) => ({ 0: ["خارج الكراج", "orange"], 1: ["بالكراج", "green"], 2: ["بالحجز", "red"] }[s] || ["—", "gray"]);
const initial = (n) => (n || "؟").trim().charAt(0);
function avatar(name, img) {
    const a = h("span", { class: "av" });
    if (img) { const i = h("img", { src: img, onerror: () => { a.replaceChildren(initial(name)); } }); a.append(i); }
    else a.append(initial(name));
    return a;
}
const emptyBox = (text, ic = "search") => h("div", { class: "empty", html: `<svg viewBox="0 0 24 24"><path d="${P[ic]}"/></svg>` }, text);
const loading = () => h("div", { class: "loading" });

function toast(msg, type = "") {
    const t = h("div", { class: "toast " + type }, msg);
    $("#toasts").append(t);
    setTimeout(() => t.classList.add("out"), 2800);
    setTimeout(() => t.remove(), 3200);
}

async function api(name, data = {}) {
    let res;
    if (IN_GAME) {
        res = await fetch(`https://${RES}/req`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, data }) })
            .then((r) => r.text())
            .then((t) => { try { let v = JSON.parse(t); if (typeof v === "string") v = JSON.parse(v); return v; } catch (e) { console.log("[ar_mdt] " + name + " رد غلط: " + String(t).slice(0, 300)); return null; } })
            .catch((e) => { console.log("[ar_mdt] " + name + " فشل: " + e); return null; });
    } else res = { data: MOCK(name, data) };
    if (!res) { toast("ما وصل رد من السيرفر (" + name + ")", "err"); return null; }
    if (res.err) { toast(res.err, "err"); return null; }
    return fixEmpty(res.data);
}

// لوا يرسل الجدول الفاضي {} بدل [] — نحوله مصفوفة حتى ما ينكسر شي
function fixEmpty(v) {
    if (Array.isArray(v)) return v.map(fixEmpty);
    if (v && typeof v === "object") {
        const keys = Object.keys(v);
        if (!keys.length) return [];
        for (const k of keys) v[k] = fixEmpty(v[k]);
    }
    return v;
}

function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }

/* ---------- الصفحات ---------- */
const PAGES = [
    { id: "dash", label: "الرئيسية", icon: "dash", sub: "نظرة عامة على الوضع" },
    { id: "dispatch", label: "خريطة البلاغات", icon: "siren", sub: "البلاغات المباشرة وأماكنها على الخريطة", badge: "dispatch" },
    { id: "citizens", label: "المواطنين", icon: "user", sub: "البحث بالاسم أو رقم الهوية أو الهاتف" },
    { id: "cases", label: "القضايا والسجن", icon: "gavel", sub: "تسجيل قضية وسجن المتهم، وكل القضايا اللي كتبوها الضباط" },
    { id: "vehicles", label: "المركبات", icon: "car", sub: "البحث برقم اللوحة" },
    { id: "reports", label: "التقارير", icon: "report", sub: "تقارير الحوادث والتحقيقات" },
    { id: "warrants", label: "أوامر القبض", icon: "warrant", sub: "المطلوبين للعدالة", badge: "warrants" },
    { id: "bolos", label: "التعميمات", icon: "bolo", sub: "تعميمات على أشخاص ومركبات", badge: "bolos" },
    { id: "penal", label: "قانون العقوبات", icon: "law", sub: "الغرامات ومدد السجن" },
    { id: "units", label: "الوحدات", icon: "units", sub: "الوحدات بالدوام هسه" },
];

function renderNav() {
    const nav = $("#nav");
    nav.replaceChildren(...PAGES.map((p) => h("div", { class: "nv" + (PAGE === p.id ? " on" : ""), onclick: () => go(p.id) },
        icon(p.icon), p.label,
        p.badge && COUNTS[p.badge] ? h("span", { class: "cnt" }, COUNTS[p.badge]) : null)));
}

let pageToken = 0;
function go(id, arg) {
    PAGE = id;
    const p = PAGES.find((x) => x.id === id);
    $("#pageTitle").textContent = p.label;
    $("#pageSub").textContent = p.sub;
    renderNav();
    const box = $("#page");
    box.replaceChildren(loading());
    box.classList.remove("page-anim"); void box.offsetWidth; box.classList.add("page-anim");
    const tok = ++pageToken;
    Promise.resolve().then(() => VIEWS[id](arg))
        .then((el) => { if (tok === pageToken && el) box.replaceChildren(el); })
        .catch((e) => {
            console.log("[ar_mdt] " + id + ": " + (e && e.stack || e));
            if (tok === pageToken) box.replaceChildren(emptyBox("خطأ بالصفحة: " + (e && e.message || e), "warrant"));
        });
}

/* ================= الرئيسية ================= */
const VIEWS = {};
VIEWS.dash = async () => {
    const d = await api("dashboard");
    if (!d) return emptyBox("ما كدرت أجيب البيانات");
    COUNTS = d.counts; renderNav();
    const stat = (label, val, ic, c, page) => h("div", { class: "st", style: `--c:${c}`, onclick: () => go(page) }, icon(ic), h("small", null, label), h("b", null, val));
    const statusOf = (id) => (CFG.statuses || []).find((s) => s.id === id) || { label: id, color: "#3ddc97" };
    return h("div", null,
        h("div", { class: "stats" },
            stat("وحدات بالدوام", d.counts.units, "units", "var(--blue)", "units"),
            stat("أوامر قبض فعالة", d.counts.warrants, "warrant", "var(--red)", "warrants"),
            stat("تعميمات فعالة", d.counts.bolos, "bolo", "var(--orange)", "bolos"),
            stat("تقارير اليوم", d.counts.reports, "report", "var(--cyan)", "reports"),
            stat("قضايا اليوم", d.counts.convictions, "gavel", "var(--gold)", "cases")),
        h("div", { class: "dash" },
            h("div", { class: "card" }, h("h3", null, h("i"), "الوحدات بالدوام", h("span", { class: "more", onclick: () => go("units") }, "الكل")),
                d.units.length ? d.units.slice(0, 9).map((u) => {
                    const s = statusOf(u.status);
                    return h("div", { class: "li" }, avatar(u.name),
                        h("div", { class: "t" }, h("b", null, u.name), h("small", null, u.role ? u.rank + " • " + u.role : u.rank)),
                        h("span", { class: "tag", style: `background:${s.color}22;color:${s.color}` }, s.label),
                        h("span", { class: "tag" + (u.callsign ? "" : " gray"), style: "direction:ltr" }, u.callsign || "—"));
                }) : emptyBox("ماكو أحد بالدوام", "units")),
            h("div", { class: "card" }, h("h3", null, h("i"), "آخر التقارير", h("span", { class: "more", onclick: () => go("reports") }, "الكل")),
                d.reports.length ? d.reports.map((r) => h("div", { class: "li", onclick: () => go("reports", r.id) },
                    h("span", { class: "ico" }, icon("report")),
                    h("div", { class: "t" }, h("b", null, `#${r.id} ${r.title}`), h("small", null, (r.type || "") + " • " + (r.author || ""))),
                    h("span", { class: "time" }, ago(r.ts)))) : emptyBox("ماكو تقارير", "report")),
            h("div", { class: "col" },
                h("div", { class: "card" }, h("h3", null, h("i", { style: "background:var(--red);box-shadow:0 0 8px var(--red)" }), "المطلوبين", h("span", { class: "more", onclick: () => go("warrants") }, "الكل")),
                    d.warrants.length ? d.warrants.map((w) => h("div", { class: "li", onclick: () => go("citizens", w.citizenid) },
                        h("span", { class: "ico red" }, icon("warrant")),
                        h("div", { class: "t" }, h("b", null, w.name), h("small", null, w.reason)),
                        h("span", { class: "time" }, ago(w.ts)))) : emptyBox("ماكو مطلوبين", "warrant")),
                h("div", { class: "card" }, h("h3", null, h("i", { style: "background:var(--orange);box-shadow:0 0 8px var(--orange)" }), "التعميمات", h("span", { class: "more", onclick: () => go("bolos") }, "الكل")),
                    d.bolos.length ? d.bolos.map((b) => h("div", { class: "li", onclick: () => b.plate ? go("vehicles", b.plate) : go("bolos") },
                        h("span", { class: "ico orange" }, icon(b.kind === "vehicle" ? "car" : "user")),
                        h("div", { class: "t" }, h("b", null, b.title), h("small", null, b.plate || "شخص")),
                        h("span", { class: "time" }, ago(b.ts)))) : emptyBox("ماكو تعميمات", "bolo")))));
};

/* ================= المواطنين ================= */
const CIT = { q: "", list: [], sel: null };
VIEWS.citizens = async (cid) => {
    const listBox = h("div", { class: "scroll" });
    const right = h("div", { class: "card scroll" });
    const drawList = () => {
        listBox.replaceChildren(...(CIT.list.length ? CIT.list.map((c) => h("div", { class: "li" + (CIT.sel === c.cid ? " on" : ""), onclick: () => { CIT.sel = c.cid; drawList(); openProfile(c.cid, right); } },
            avatar(c.name, c.image),
            h("div", { class: "t" }, h("b", null, c.name), h("small", null, `${c.cid} • ${c.phone || ""}`)),
            c.wanted ? h("span", { class: "tag red" }, "مطلوب") : null)) : [emptyBox(CIT.q ? "ماكو نتائج" : "اكتب اسم أو رقم هوية للبحث", "user")]));
    };
    const doSearch = async (q) => {
        CIT.q = q;
        if (!q.trim()) { CIT.list = []; return drawList(); }
        listBox.replaceChildren(loading());
        CIT.list = (await api("searchCitizens", { q })) || [];
        drawList();
    };
    const inp = h("input", { class: "in", placeholder: "الاسم / رقم الهوية / الهاتف...", value: CIT.q, oninput: debounce((e) => doSearch(e.target.value), 350) });
    drawList();
    if (cid) { CIT.sel = cid; openProfile(cid, right); }
    else if (CIT.sel) openProfile(CIT.sel, right);
    else right.replaceChildren(emptyBox("اختار مواطن حتى يطلع ملفه", "user"));
    setTimeout(() => inp.focus(), 50);
    return h("div", { class: "split" },
        h("div", { class: "card" }, h("div", { class: "search", style: "margin-bottom:10px" }, icon("search"), inp), listBox),
        right);
};

async function openProfile(cid, box) {
    box.replaceChildren(loading());
    const p = await api("getProfile", { cid });
    if (!p) return box.replaceChildren(emptyBox("الملف مو موجود", "user"));
    const st = { image: p.image || "", notes: p.notes || "", tags: [...(p.tags || [])] };
    const wanted = p.warrants.some((w) => Number(w.active) === 1);

    const photo = h("div", { class: "photo", title: "غيّر الصورة", onclick: () => imageModal(st.image, (url) => { st.image = url; drawPhoto(); save(); }) });
    const drawPhoto = () => {
        photo.replaceChildren();
        if (st.image) photo.append(h("img", { src: st.image, onerror: (e) => e.target.remove() }));
        else photo.append(h("span", { html: `<svg viewBox="0 0 24 24"><path d="${P.user}"/></svg>`, style: "display:contents" }));
        photo.append(h("span", { class: "ed" }, "تغيير الصورة"));
    };
    drawPhoto();

    const save = async (quiet) => {
        const ok = await api("saveProfile", { cid, image: st.image, notes: st.notes, tags: st.tags });
        if (ok && !quiet) toast("انحفظ الملف", "ok");
    };

    const tagBox = h("div", { class: "chips" });
    const drawTags = () => tagBox.replaceChildren(...(CFG.tags || []).map((t) =>
        h("span", { class: "tag sel" + (st.tags.includes(t) ? " on" : "") + (["خطر", "مسلح", "مطلوب"].includes(t) ? " red" : ""), onclick: () => {
            st.tags = st.tags.includes(t) ? st.tags.filter((x) => x !== t) : [...st.tags, t]; drawTags(); save(true);
        } }, t)));
    drawTags();

    const lics = h("div", { class: "lics" }, (CFG.licenses || []).map((l) => {
        const el = h("div", { class: "lic" + (p.licenses[l.id] ? " on" : ""), onclick: async () => {
            const val = !el.classList.contains("on");
            if (await api("setLicense", { cid, id: l.id, value: val })) { el.classList.toggle("on", val); toast((val ? "انعطت " : "انسحبت ") + l.label, "ok"); }
        } }, h("span", { class: "sw" }), l.label);
        return el;
    }));

    const fact = (k, v) => h("div", { class: "fact" }, h("small", null, k), h("b", null, v || "—"));
    const notes = h("textarea", { class: "in", style: "min-height:80px", placeholder: "ملاحظات عن المواطن...", oninput: (e) => (st.notes = e.target.value) });
    notes.value = st.notes;

    // التبويبات
    const tabBody = h("div");
    const tabs = [
        { id: "conv", label: "السوابق", n: p.convictions.length, draw: () => p.convictions.length ? p.convictions.map((c) => h("div", { class: "rec" },
            h("div", { class: "rh" }, h("b", null, parse(c.charges).length + " تهمة"),
                h("span", { class: "tag green" }, money(c.fine) + (Number(c.fined) ? "" : " (ما انسحبت)")),
                c.jail ? h("span", { class: "tag orange" }, c.jail + " شهر" + (Number(c.jailed) ? "" : " (ما انسجن)")) : null,
                h("span", { class: "time" }, ago(c.ts))),
            h("div", { class: "chips" }, parse(c.charges).map((x) => h("span", { class: "tag gray" }, x))),
            c.description ? h("div", { style: "margin-top:6px;line-height:1.7;white-space:pre-wrap" }, c.description) : null,
            h("small", { class: "dim", style: "display:block;margin-top:5px" }, `قضية #${c.id} • بواسطة: ` + (c.author || "") + (c.note ? " • " + c.note : "")))) : emptyBox("سجله نظيف", "gavel") },
        { id: "war", label: "أوامر القبض", n: p.warrants.filter((w) => Number(w.active) === 1).length, draw: () => p.warrants.length ? p.warrants.map((w) => h("div", { class: "rec" },
            h("div", { class: "rh" }, h("b", null, w.reason), Number(w.active) ? h("span", { class: "tag red" }, "فعال") : h("span", { class: "tag gray" }, "منفذ"), h("span", { class: "time" }, ago(w.ts))),
            h("div", { class: "chips" }, parse(w.charges).map((x) => h("span", { class: "tag gray" }, x))))) : emptyBox("ماكو أوامر قبض", "warrant") },
        { id: "rep", label: "التقارير", n: p.reports.length, draw: () => p.reports.length ? p.reports.map((r) => h("div", { class: "li", onclick: () => go("reports", r.id) },
            h("span", { class: "ico" }, icon("report")), h("div", { class: "t" }, h("b", null, `#${r.id} ${r.title}`), h("small", null, r.type || "")), h("span", { class: "time" }, ago(r.ts)))) : emptyBox("ماكو تقارير", "report") },
        { id: "veh", label: "المركبات", n: p.vehicles.length, draw: () => p.vehicles.length ? p.vehicles.map((v) => { const s = vState(v.state); return h("div", { class: "li", onclick: () => go("vehicles", v.plate) },
            h("span", { class: "ico" }, icon("car")), h("div", { class: "t" }, h("b", null, v.label), h("small", { style: "direction:ltr;text-align:right" }, v.plate)), h("span", { class: "tag " + s[1] }, s[0])); }) : emptyBox("ما عنده مركبات", "car") },
    ];
    let curTab = "conv";
    const tabBar = h("div", { class: "tabs" });
    const drawTabs = () => {
        tabBar.replaceChildren(...tabs.map((t) => h("div", { class: "tab" + (curTab === t.id ? " on" : ""), onclick: () => { curTab = t.id; drawTabs(); } }, t.label, h("span", { class: "n" }, t.n))));
        tabBody.replaceChildren(...[tabs.find((t) => t.id === curTab).draw()].flat());
    };
    drawTabs();

    box.replaceChildren(h("div", { class: "prof" },
        h("div", { class: "pHead" }, photo,
            h("div", { class: "pInfo" },
                h("div", { class: "pName" }, h("b", null, p.name),
                    wanted ? h("span", { class: "tag red" }, "⚠ مطلوب") : null,
                    p.injail > 0 ? h("span", { class: "tag orange" }, `بالسجن ${p.injail} شهر`) : null,
                    p.online ? h("span", { class: "tag green" }, "متصل • ID " + p.serverId) : h("span", { class: "tag gray" }, "غير متصل")),
                h("div", { class: "facts" },
                    fact("رقم الهوية", p.cid), fact("تاريخ الميلاد", p.dob), fact("الجنس", gender(p.gender)),
                    fact("الجنسية", p.nationality), fact("الهاتف", p.phone), fact("الوظيفة", p.job + (p.jobGrade ? " - " + p.jobGrade : "")),
                    fact("البصمة", p.fingerprint), fact("فصيلة الدم", p.bloodtype), fact("السوابق", p.convictions.length + " حكم")),
                lics)),
        h("div", null, h("label", { class: "lb" }, "التصنيف"), tagBox),
        h("div", null, h("label", { class: "lb" }, "الملاحظات"), notes),
        h("div", { class: "row" },
            h("button", { class: "btn pri", onclick: () => save() }, "حفظ الملف"),
            h("button", { class: "btn red", onclick: () => go("cases", { suspect: { cid: p.cid, name: p.name, online: p.online, id: p.serverId } }) }, icon("gavel"), "قضية / سجن"),
            h("button", { class: "btn", onclick: () => warrantModal({ cid: p.cid, name: p.name }, () => openProfile(cid, box)) }, "إصدار أمر قبض")),
        h("div", null, tabBar, tabBody)));
}

/* ================= خريطة البلاغات ================= */
// طلب مباشر للكلاينت (مو للسيرفر)
async function nui(name, data = {}) {
    if (!IN_GAME) return MOCK_NUI(name, data);
    try {
        const t = await fetch(`https://${RES}/${name}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(data) }).then((r) => r.text());
        let v = JSON.parse(t);
        if (typeof v === "string") v = JSON.parse(v);
        return v;
    } catch (e) { return null; }
}

// خريطة GTA الحقيقية (صور Rockstar) — إحداثيات اللعبة: lat = y ، lng = x
const MAP_STYLES = { render: "قمر صناعي", game: "خريطة اللعبة", print: "أطلس" };
const DSP = { list: [], sel: null, me: null, style: "render", view: null };
let GTA_CRS = null;
function gtaCrs() {
    if (GTA_CRS || typeof L === "undefined") return GTA_CRS;
    GTA_CRS = L.extend({}, L.CRS.Simple, {
        projection: L.Projection.LonLat,
        scale: (z) => Math.pow(2, z),
        zoom: (s) => Math.log(s) / Math.LN2,
        distance: (a, b) => Math.hypot(b.lng - a.lng, b.lat - a.lat),
        // مضبوطة على معالم الخريطة (المطار، الميناء، مطار ساندي، السجن، باليتو)
        transformation: new L.Transformation(0.0275, 116.5, -0.0275, 237.5),
        infinite: true, // بدونها Leaflet يحسب العالم ±180 بس ويجيب صورة وحدة
    });
    return GTA_CRS;
}
const ll = (c) => L.latLng(c.y, c.x);

VIEWS.dispatch = async () => {
    const res = await api("dispatch");
    if (!res) return emptyBox("ما كدرت أجيب البلاغات", "siren");
    if (res.off) return emptyBox("سكربت البلاغات (ar_dispatch) مو شغال", "siren");
    DSP.list = res.list || [];
    COUNTS.dispatch = 0; renderNav();
    DSP.me = await nui("mypos");
    const need = DSP.list.filter((a) => !a.street);
    if (need.length) {
        const names = (await nui("streets", need.map((a) => a.coords))) || [];
        need.forEach((a, i) => { if (names[i]) { a.street = names[i].street; a.zone = names[i].zone; } });
    }

    const listBox = h("div", { class: "scroll" });
    const detail = h("div", { class: "dDetail hidden" });
    const mapEl = h("div", { class: "dmap" });
    let map = null, tiles = null;
    const markers = new Map();
    const layer = typeof L !== "undefined" ? L.layerGroup() : null;

    const pinIcon = (a, on) => {
        const fresh = Date.now() / 1000 - a.time < 300;
        return L.divIcon({
            className: "", iconSize: [34, 34], iconAnchor: [17, 17],
            html: `<div class="dPin${on ? " on" : ""}${fresh ? " fresh" : ""}" style="--c:${a.color}"><span>${String(a.code).replace("10-", "")}</span></div>`,
        });
    };

    const drawMarkers = () => {
        if (!map) return;
        layer.clearLayers(); markers.clear();
        if (DSP.me) L.marker(ll(DSP.me), { icon: L.divIcon({ className: "", iconSize: [20, 20], iconAnchor: [10, 10], html: '<div class="mePin"></div>' }), zIndexOffset: 1000 }).bindTooltip("أنت", { direction: "top", offset: [0, -8] }).addTo(layer);
        [...DSP.list].reverse().forEach((a) => {
            const on = DSP.sel && DSP.sel.id === a.id;
            const m = L.marker(ll(a.coords), { icon: pinIcon(a, on), zIndexOffset: on ? 900 : 0 })
                .bindTooltip(`${a.code} ${a.title}`, { direction: "top", offset: [0, -16] })
                .on("click", () => select(a, true));
            m.addTo(layer); markers.set(a.id, m);
        });
    };

    const select = (a, fromMap) => {
        DSP.sel = a;
        drawList(); drawMarkers();
        if (!a) return detail.classList.add("hidden");
        detail.classList.remove("hidden");
        detail.style.setProperty("--c", a.color);
        detail.replaceChildren(...[
            h("div", { class: "row" }, h("span", { class: "dCode" }, a.code), h("b", { style: "flex:1;font-size:16px" }, a.title), h("span", { class: "time" }, ago(a.time)), h("button", { class: "x", style: "width:28px;height:28px", onclick: () => select(null) }, "✕")),
            h("div", { class: "muted", style: "margin:4px 0 6px" }, (a.street || "") + (a.zone ? " • " + a.zone : "")),
            a.message ? h("div", { class: "rec", style: "margin-bottom:6px" }, a.message) : null,
            h("div", { class: "chips", style: "margin-bottom:8px" },
                a.gender ? h("span", { class: "tag" }, "المشتبه: " + a.gender) : null,
                (a.details || []).map((d) => h("span", { class: "tag" }, d[0] + ": " + d[1])),
                a.vehicle && a.vehicle.model ? h("span", { class: "tag" }, "🚗 " + a.vehicle.model) : null,
                a.vehicle && a.vehicle.plate ? h("span", { class: "tag", style: "background:#eef3fb;color:#0a1a33;direction:ltr;cursor:pointer", onclick: () => go("vehicles", a.vehicle.plate) }, a.vehicle.plate) : null),
            h("div", { class: "row" },
                h("button", { class: "btn pri", onclick: async () => { await nui("gps", { id: a.id, coords: a.coords }); toast("انحدد الموقع، وانسجلت مستجيب", "ok"); a.responders = [...(a.responders || []), (ME.callsign ? "[" + ME.callsign + "] " : "") + ME.rank + " " + ME.name]; select(a, true); } }, icon("pin"), "GPS واستجابة"),
                h("small", { class: "dim", style: "flex:1" }, (a.responders || []).length ? "المستجيبين: " + a.responders.join("، ") : "محد مستجيب بعد"))].filter(Boolean));
        if (!fromMap && map) map.flyTo(ll(a.coords), 3.5, { duration: 0.6 });
    };

    const drawList = () => listBox.replaceChildren(...(DSP.list.length ? DSP.list.map((a) => h("div", { class: "li" + (DSP.sel && DSP.sel.id === a.id ? " on" : ""), style: `border-right:3px solid ${a.color}`, onclick: () => select(a) },
        h("span", { class: "dCode", style: `--c:${a.color}` }, a.code),
        h("div", { class: "t" }, h("b", null, a.title), h("small", null, (a.street || "—") + (a.zone ? " • " + a.zone : ""))),
        h("div", { style: "text-align:left" }, h("span", { class: "time", style: "display:block" }, ago(a.time)),
            (a.responders || []).length ? h("small", { style: "color:var(--green);font-size:11px;font-weight:800" }, "مستجيبين " + a.responders.length) : null)))
        : [emptyBox("ماكو بلاغات هسه", "siren")]));

    const setStyle = (s) => {
        DSP.style = s;
        if (tiles) map.removeLayer(tiles);
        tiles = L.tileLayer(`https://s.rsg.sc/sc/images/games/GTAV/map/${s}/{z}/{x}/{y}.jpg`, { minZoom: 0, zoomOffset: 1, maxNativeZoom: 6, maxZoom: 7, noWrap: true, tileSize: 256,
            errorTileUrl: "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" }).addTo(map);
        tiles.bringToBack();
        styleBar.querySelectorAll("button").forEach((b) => b.classList.toggle("pri", b.dataset.s === s));
    };
    const styleBar = h("div", { class: "row", style: "gap:6px" }, Object.entries(MAP_STYLES).map(([k, v]) => h("button", { class: "btn sm", "data-s": k, onclick: () => setStyle(k) }, v)));

    // الخريطة تنبني بعد ما تنضاف للصفحة
    const mount = () => {
        if (typeof L === "undefined") { mapEl.replaceChildren(emptyBox("الخريطة ما تحملت (تحتاج إنترنت)", "siren")); return; }
        if (!mapEl.isConnected) return setTimeout(mount, 30);
        map = L.map(mapEl, { crs: gtaCrs(), minZoom: 0, maxZoom: 7, zoomControl: false, attributionControl: false, zoomSnap: 0.25, zoomDelta: 0.5, wheelPxPerZoomLevel: 90,
            maxBounds: L.latLngBounds([[-6000, -5500], [9500, 7000]]), maxBoundsViscosity: 0.8 });
        DSP.map = map;
        L.control.zoom({ position: "bottomleft" }).addTo(map);
        layer.addTo(map);
        setStyle(DSP.style);
        if (DSP.view) map.setView(DSP.view.c, DSP.view.z); else map.setView(L.latLng(2000, 300), 0.75);
        map.on("moveend", () => (DSP.view = { c: map.getCenter(), z: map.getZoom() }));
        map.on("click", () => DSP.sel && select(null));
        drawMarkers();
        if (DSP.sel) { const s = DSP.list.find((a) => a.id === DSP.sel.id); if (s) select(s, true); else DSP.sel = null; }
        setTimeout(() => map.invalidateSize(), 50);
    };
    setTimeout(mount, 30);

    DSP.refresh = (a) => {
        DSP.list.unshift(a);
        nui("streets", [a.coords]).then((n) => { if (n && n[0]) { a.street = n[0].street; a.zone = n[0].zone; } drawList(); drawMarkers(); });
    };

    drawList();
    const viewBtn = (label, c, z) => h("button", { class: "btn sm", onclick: () => map && map.flyTo(L.latLng(c[1], c[0]), z, { duration: 0.6 }) }, label);
    return h("div", { class: "split", style: "grid-template-columns:330px 1fr" },
        h("div", { class: "card" }, h("h3", null, h("i", { style: "background:var(--red);box-shadow:0 0 8px var(--red)" }), "آخر البلاغات", h("span", { class: "more", onclick: () => go("dispatch") }, "⟳ تحديث")), listBox),
        h("div", { class: "card mapCard" },
            h("div", { class: "row mapTools" },
                viewBtn("كل الخريطة", [300, 2000], 0.75), viewBtn("لوس سانتوس", [-300, -1200], 2.5), viewBtn("الشمال", [800, 4600], 1.75),
                DSP.me ? h("button", { class: "btn sm", onclick: () => map && map.flyTo(ll(DSP.me), 3.5, { duration: 0.6 }) }, icon("pin"), "موقعي") : null,
                h("div", { style: "flex:1" }), styleBar),
            mapEl, detail));
};

/* ================= القضايا والسجن ================= */
const CASES = { q: "", sel: null };
VIEWS.cases = async (arg) => {
    const listBox = h("div", { class: "scroll" });
    const right = h("div", { class: "card scroll" });
    const load = async () => {
        listBox.replaceChildren(loading());
        const list = (await api("listCases", { q: CASES.q })) || [];
        listBox.replaceChildren(...(list.length ? list.map((c) => h("div", { class: "li" + (CASES.sel && CASES.sel.id === c.id ? " on" : ""), onclick: () => { CASES.sel = c; load(); showCase(c, right); } },
            h("span", { class: "ico " + (Number(c.jailed) ? "red" : "orange") }, icon("gavel")),
            h("div", { class: "t" }, h("b", null, `#${c.id} ${c.name || c.citizenid}`), h("small", null, parse(c.charges).join("، ") || "—")),
            h("div", { style: "text-align:left" }, h("span", { class: "time", style: "display:block" }, ago(c.ts)), c.jail ? h("small", { style: "color:var(--orange);font-weight:800;font-size:11px" }, c.jail + " شهر") : null)))
            : [emptyBox(CASES.q ? "ماكو قضايا بهذا البحث" : "ماكو قضايا بعد", "gavel")]));
    };
    const inp = h("input", { class: "in", placeholder: "ابحث بالاسم، التهمة، الضابط، الرقم...", value: CASES.q, oninput: debounce((e) => { CASES.q = e.target.value; load(); }, 350) });
    load();
    if (arg && arg.suspect) { CASES.sel = null; caseForm(right, arg.suspect, load); }
    else if (CASES.sel) showCase(CASES.sel, right);
    else caseForm(right, null, load);
    return h("div", { class: "split", style: "grid-template-columns:360px 1fr" },
        h("div", { class: "card" },
            h("div", { class: "row", style: "margin-bottom:10px" }, h("div", { class: "search", style: "flex:1" }, icon("search"), inp),
                h("button", { class: "btn pri", title: "قضية جديدة", onclick: () => { CASES.sel = null; load(); caseForm(right, null, load); } }, icon("plus"))),
            listBox),
        right);
};

function showCase(c, box) {
    const charges = parse(c.charges);
    box.replaceChildren(h("div", { class: "prof" },
        h("div", { class: "row" },
            h("span", { class: "ico " + (Number(c.jailed) ? "red" : "orange"), style: "width:46px;height:46px" }, icon("gavel")),
            h("div", { style: "flex:1" },
                h("b", { style: "font-size:20px;display:block;cursor:pointer", onclick: () => go("citizens", c.citizenid) }, (c.name || c.citizenid) + " ↗"),
                h("small", { class: "muted" }, `قضية #${c.id} • ${fullDate(c.ts)}`)),
            h("button", { class: "btn", onclick: () => go("citizens", c.citizenid) }, icon("user"), "ملف المتهم")),
        h("div", { class: "facts" },
            h("div", { class: "fact" }, h("small", null, "مدة السجن"), h("b", { style: "color:var(--orange)" }, (c.jail || 0) + " شهر " + (c.jail ? (Number(c.jailed) ? "✓ انسجن" : "✗ ما انسجن") : ""))),
            h("div", { class: "fact" }, h("small", null, "الغرامة"), h("b", { style: "color:var(--green)" }, money(c.fine) + " " + (c.fine ? (Number(c.fined) ? "✓ انسحبت" : "✗ ما انسحبت") : ""))),
            h("div", { class: "fact" }, h("small", null, "الضابط"), h("b", null, c.author || "—"))),
        h("div", null, h("label", { class: "lb" }, "المخالفات"), h("div", { class: "chips" }, charges.length ? charges.map((x) => h("span", { class: "tag red" }, x)) : h("span", { class: "dim" }, "—"))),
        h("div", null, h("label", { class: "lb" }, "شنو سوا (تفاصيل القضية)"),
            h("div", { class: "rec", style: "white-space:pre-wrap;line-height:1.8;min-height:80px" }, c.description || "ماكو تفاصيل مكتوبة")),
        c.note ? h("div", { class: "rec", style: "border-color:rgba(255,169,77,.4);color:var(--orange)" }, c.note) : null));
}

async function caseForm(box, suspect, reload) {
    const st = { suspect: suspect || null, sel: new Set(), touched: false };
    const jail = h("input", { class: "in", type: "number", min: 0, value: 0, style: "font-size:18px;font-weight:800;text-align:center", oninput: () => (st.touched = true) });
    const fine = h("input", { class: "in", type: "number", min: 0, value: 0, style: "font-size:18px;font-weight:800;text-align:center", oninput: () => (st.touched = true) });
    const extra = h("input", { class: "in", placeholder: "مخالفة مو موجودة بالقانون؟ اكتبها هنا (اختياري)" });
    const desc = h("textarea", { class: "in", style: "min-height:130px", placeholder: "اكتب شنو سوا بالتفصيل: وين انمسك، شنو لكيتو عنده، شنو صار..." });
    const doJail = h("input", { type: "checkbox", checked: true });
    const doFine = h("input", { type: "checkbox", checked: true });
    const sum = () => {
        let f = 0, j = 0;
        (CFG.penal || []).forEach((c) => c.items.forEach((i) => { if (st.sel.has(i.id)) { f += i.fine; j += i.jail; } }));
        return { f, j };
    };
    const recalc = (force) => {
        if (st.touched && !force) return;
        const s = sum();
        jail.value = s.j; fine.value = s.f;
        if (force) st.touched = false;
    };
    const grid = penalGrid({ selected: st.sel, pick: (i) => { st.sel.has(i.id) ? st.sel.delete(i.id) : st.sel.add(i.id); recalc(); } });
    const pSearch = h("input", { class: "in", placeholder: "ابحث عن مخالفة...", oninput: (e) => grid.redraw(e.target.value.trim()) });

    // المتهم: القريبين أو البحث
    const susBox = h("div");
    const drawSuspect = async () => {
        if (st.suspect) {
            const s = st.suspect;
            susBox.replaceChildren(h("div", { class: "li on" }, avatar(s.name),
                h("div", { class: "t" }, h("b", null, s.name), h("small", null, s.cid + (s.id ? " • ID " + s.id : ""))),
                s.online === false ? h("span", { class: "tag gray" }, "غير متصل") : null,
                h("button", { class: "btn sm", onclick: () => { st.suspect = null; drawSuspect(); } }, "تغيير")));
            doJail.checked = s.online !== false;
            return;
        }
        const near = h("div", null, loading());
        susBox.replaceChildren(h("div", { class: "row", style: "margin-bottom:8px" },
            h("b", { style: "flex:1;font-size:12.5px;color:var(--mute)" }, "الأشخاص اللي يمك (بالزنزانة):"),
            h("button", { class: "btn sm", onclick: () => drawSuspect() }, "⟳ تحديث"),
            h("button", { class: "btn sm", onclick: () => citizenPicker((c) => { st.suspect = c; drawSuspect(); }) }, icon("search"), "بحث بالاسم")), near);
        const list = (await api("nearby")) || [];
        near.replaceChildren(...(list.length ? list.map((p) => h("div", { class: "li", onclick: () => { st.suspect = { ...p, online: true }; drawSuspect(); } },
            avatar(p.name), h("div", { class: "t" }, h("b", null, p.name), h("small", null, `ID ${p.id} • ${p.dist} متر`)),
            p.cuffed ? h("span", { class: "tag orange" }, "مكلبش") : null,
            p.injail ? h("span", { class: "tag red" }, "بالسجن") : null,
            h("button", { class: "btn sm pri" }, "اختيار")))
            : [h("div", { class: "rec dim", style: "text-align:center" }, "ماكو أحد يمك. روح يم المتهم واضغط تحديث، أو ابحث باسمه")]));
    };
    drawSuspect();

    const submit = async (btn) => {
        if (!st.suspect) return toast("اختار المتهم أول", "err");
        btn.disabled = true;
        const r = await api("sentence", {
            cid: st.suspect.cid, charges: [...st.sel], extra: extra.value,
            jail: Number(jail.value) || 0, fine: Number(fine.value) || 0,
            description: desc.value, doJail: doJail.checked, doFine: doFine.checked,
        });
        btn.disabled = false;
        if (!r) return;
        if (!r.ok) return toast(r.msg, "err");
        toast(r.msg, "ok");
        await reload();
        const all = (await api("listCases", { q: String(r.id) })) || [];
        const c = all.find((x) => x.id === r.id);
        if (c) { CASES.sel = c; showCase(c, box); reload(); } else caseForm(box, null, reload);
    };
    const sendBtn = h("button", { class: "btn red", style: "height:42px;font-size:14px;padding:0 22px", onclick: (e) => submit(e.currentTarget) }, icon("gavel"), "تسجيل القضية");

    const step = (n, t) => h("div", { class: "catH" }, h("span", { class: "tag", style: "font-size:12px" }, n), t);
    box.replaceChildren(h("div", { class: "col", style: "gap:12px" },
        h("b", { style: "font-size:18px" }, "قضية جديدة"),
        step("1", "المتهم"), susBox,
        step("2", "المخالفات"), h("div", { class: "search" }, icon("search"), pSearch), grid, extra,
        step("3", "الحكم"),
        h("div", { class: "row", style: "align-items:flex-end" },
            h("div", { style: "flex:1" }, h("label", { class: "lb" }, "مدة السجن (شهر)"), jail),
            h("div", { style: "flex:1" }, h("label", { class: "lb" }, "الغرامة ($)"), fine),
            h("button", { class: "btn", title: "يرجع المجموع حسب المخالفات المختارة", onclick: () => recalc(true) }, "⟳ حسب القانون")),
        step("4", "شنو سوا"), desc,
        h("div", { class: "row", style: "padding-top:6px;border-top:1px solid var(--edge)" },
            h("label", { class: "chk" }, doJail, "سجنه هسه (لازم يكون يمك)"),
            h("label", { class: "chk" }, doFine, "اسحب الغرامة"),
            h("div", { style: "flex:1" }), sendBtn)));
}

/* ================= المركبات ================= */
const VEH = { q: "", list: [], sel: null };
VIEWS.vehicles = async (plate) => {
    const listBox = h("div", { class: "scroll" });
    const right = h("div", { class: "card scroll" });
    const drawList = () => listBox.replaceChildren(...(VEH.list.length ? VEH.list.map((v) => h("div", { class: "li" + (VEH.sel === v.plate ? " on" : ""), onclick: () => { VEH.sel = v.plate; drawList(); openVehicle(v.plate, right); } },
        h("span", { class: "ico" + (v.stolen ? " red" : "") }, icon("car")),
        h("div", { class: "t" }, h("b", { style: "direction:ltr;text-align:right" }, v.plate), h("small", null, `${v.label} • ${v.owner}`)),
        v.stolen ? h("span", { class: "tag red" }, "مسروقة") : null)) : [emptyBox(VEH.q ? "ماكو نتائج" : "اكتب رقم اللوحة", "car")]));
    const doSearch = async (q) => {
        VEH.q = q;
        if (!q.trim()) { VEH.list = []; return drawList(); }
        listBox.replaceChildren(loading());
        VEH.list = (await api("searchVehicles", { q: q.trim() })) || [];
        drawList();
    };
    const inp = h("input", { class: "in", placeholder: "رقم اللوحة...", value: VEH.q, style: "direction:ltr;text-align:right", oninput: debounce((e) => doSearch(e.target.value), 350) });
    drawList();
    if (plate) { VEH.sel = plate; openVehicle(plate, right); }
    else if (VEH.sel) openVehicle(VEH.sel, right);
    else right.replaceChildren(emptyBox("اختار مركبة حتى تطلع معلوماتها", "car"));
    setTimeout(() => inp.focus(), 50);
    return h("div", { class: "split" }, h("div", { class: "card" }, h("div", { class: "search", style: "margin-bottom:10px" }, icon("search"), inp), listBox), right);
};

async function openVehicle(plate, box) {
    box.replaceChildren(loading());
    const v = await api("getVehicle", { plate });
    if (!v) return box.replaceChildren(emptyBox("ماكو معلومات", "car"));
    let stolen = !!v.stolen;
    const s = vState(v.state);
    const notes = h("textarea", { class: "in", style: "min-height:90px", placeholder: "ملاحظات عن المركبة..." });
    notes.value = v.notes || "";
    const stolenSw = h("div", { class: "lic" + (stolen ? " on" : ""), onclick: () => { stolen = !stolen; stolenSw.classList.toggle("on", stolen); } }, h("span", { class: "sw" }), "مبلغ عنها مسروقة");
    const fact = (k, val) => h("div", { class: "fact" }, h("small", null, k), h("b", null, val ?? "—"));
    box.replaceChildren(h("div", { class: "prof" },
        h("div", { class: "row", style: "gap:18px" },
            h("div", { style: "padding:14px 26px;border-radius:14px;background:#f1f5fb;color:#0a1a33;font-size:30px;font-weight:800;letter-spacing:3px;direction:ltr;border:3px solid #1b5fd1;box-shadow:0 0 20px rgba(47,140,255,.3)" }, v.plate),
            h("div", { class: "col", style: "gap:6px" },
                h("b", { style: "font-size:20px" }, v.unknown ? "مركبة غير مسجلة" : v.label),
                h("div", { class: "row" },
                    v.unknown ? h("span", { class: "tag red" }, "ماكو مالك مسجل") : h("span", { class: "tag " + s[1] }, s[0]),
                    stolen ? h("span", { class: "tag red" }, "مسروقة") : null,
                    v.bolos.length ? h("span", { class: "tag orange" }, "عليها تعميم") : null))),
        v.unknown ? null : h("div", { class: "facts" },
            h("div", { class: "fact", style: "cursor:pointer", onclick: () => go("citizens", v.ownerCid) }, h("small", null, "المالك"), h("b", { style: "color:var(--glow)" }, v.owner + " ↗")),
            fact("رقم هوية المالك", v.ownerCid), fact("الموديل", v.model),
            fact("الكراج", v.garage), fact("المحرك", v.engine + "%"), fact("الهيكل", v.body + "%")),
        h("div", { class: "lics" }, stolenSw),
        h("div", null, h("label", { class: "lb" }, "الملاحظات"), notes),
        h("div", { class: "row" },
            h("button", { class: "btn pri", onclick: async () => { if (await api("saveVehicle", { plate: v.plate, stolen, notes: notes.value })) { toast("انحفظت معلومات المركبة", "ok"); openVehicle(plate, box); } } }, "حفظ"),
            h("button", { class: "btn", onclick: () => boloModal({ kind: "vehicle", plate: v.plate, title: v.unknown ? "" : v.label }, () => openVehicle(plate, box)) }, icon("bolo"), "تعميم على المركبة")),
        v.bolos.length ? h("div", null, h("label", { class: "lb" }, "التعميمات الفعالة"), v.bolos.map((b) => h("div", { class: "rec" },
            h("div", { class: "rh" }, h("b", null, b.title), h("span", { class: "time" }, ago(b.ts))), h("small", { class: "muted" }, b.description || "")))) : null));
}

/* ================= التقارير ================= */
const REP = { q: "", sel: null };
VIEWS.reports = async (id) => {
    const listBox = h("div", { class: "scroll" });
    const right = h("div", { class: "card scroll" });
    const load = async () => {
        listBox.replaceChildren(loading());
        const list = (await api("listReports", { q: REP.q })) || [];
        listBox.replaceChildren(...(list.length ? list.map((r) => h("div", { class: "li" + (REP.sel === r.id ? " on" : ""), onclick: () => { REP.sel = r.id; load(); openReport(r.id, right, load); } },
            h("span", { class: "ico" }, icon("report")),
            h("div", { class: "t" }, h("b", null, `#${r.id} ${r.title}`), h("small", null, (r.type || "") + " • " + (r.author || ""))),
            h("span", { class: "time" }, ago(r.ts)))) : [emptyBox("ماكو تقارير", "report")]));
    };
    const inp = h("input", { class: "in", placeholder: "ابحث بالعنوان أو المحتوى أو الرقم...", value: REP.q, oninput: debounce((e) => { REP.q = e.target.value; load(); }, 350) });
    if (id) REP.sel = Number(id);
    load();
    if (REP.sel) openReport(REP.sel, right, load); else openReport(null, right, load);
    return h("div", { class: "split" },
        h("div", { class: "card" },
            h("div", { class: "row", style: "margin-bottom:10px" }, h("div", { class: "search", style: "flex:1" }, icon("search"), inp),
                h("button", { class: "btn pri", title: "تقرير جديد", onclick: () => { REP.sel = null; load(); openReport(null, right, load); } }, icon("plus"))),
            listBox),
        right);
};

async function openReport(id, box, reload) {
    let r = { title: "", type: (CFG.reportTypes || [])[0] || "", body: "", involved: [], officers: [{ cid: ME.cid, name: (ME.rank ? ME.rank + " " : "") + ME.name, role: "" }] };
    if (id) {
        box.replaceChildren(loading());
        const got = await api("getReport", { id });
        if (!got) return box.replaceChildren(emptyBox("التقرير مو موجود", "report"));
        r = got;
    }
    const title = h("input", { class: "in", placeholder: "عنوان التقرير", value: r.title });
    const type = h("select", { class: "in" }, (CFG.reportTypes || []).map((t) => h("option", { value: t }, t)));
    type.value = r.type || "";
    const body = h("textarea", { class: "in", style: "min-height:200px", placeholder: "تفاصيل الحادث: الوقت، المكان، شنو صار، الأدلة..." });
    body.value = r.body || "";
    const roles = ["متهم", "شاهد", "ضحية", "مشتبه به"];
    const pplBox = h("div", { class: "ppl" });
    const offBox = h("div", { class: "ppl" });
    const drawPpl = () => {
        pplBox.replaceChildren(...r.involved.map((p, i) => h("span", { class: "pp" },
            h("span", { class: "go", onclick: () => go("citizens", p.cid) }, p.name),
            h("select", { onchange: (e) => (p.role = e.target.value) }, roles.map((x) => h("option", { value: x, selected: p.role === x }, x))),
            h("span", { class: "rm", onclick: () => { r.involved.splice(i, 1); drawPpl(); } }, "✕"))),
            h("button", { class: "btn sm", onclick: () => citizenPicker((c) => { if (!r.involved.some((x) => x.cid === c.cid)) r.involved.push({ cid: c.cid, name: c.name, role: "متهم" }); drawPpl(); }) }, "+ إضافة"));
        offBox.replaceChildren(...r.officers.map((p, i) => h("span", { class: "pp" }, p.name,
            h("span", { class: "rm", onclick: () => { r.officers.splice(i, 1); drawPpl(); } }, "✕"))),
            h("button", { class: "btn sm", onclick: () => unitPicker((u) => { if (!r.officers.some((x) => x.cid === u.cid)) r.officers.push({ cid: u.cid, name: u.rank + " " + u.name }); drawPpl(); }) }, "+ إضافة"));
    };
    drawPpl();
    const save = async () => {
        const res = await api("saveReport", { id: r.id, title: title.value, type: type.value, body: body.value, involved: r.involved, officers: r.officers });
        if (!res) return;
        if (!res.ok) return toast(res.msg, "err");
        toast(r.id ? "انحفظ التقرير" : "انسوى تقرير #" + res.id, "ok");
        REP.sel = res.id; reload(); openReport(res.id, box, reload);
    };
    box.replaceChildren(h("div", { class: "editor" },
        h("div", { class: "row" }, h("b", { style: "font-size:17px;flex:1" }, r.id ? `تقرير #${r.id}` : "تقرير جديد"),
            r.id ? h("span", { class: "time" }, `${r.author || ""} • ${fullDate(r.ts)}`) : null),
        h("div", { class: "row", style: "align-items:flex-end" },
            h("div", { style: "flex:2" }, h("label", { class: "lb" }, "العنوان"), title),
            h("div", { style: "flex:1" }, h("label", { class: "lb" }, "النوع"), type)),
        h("div", null, h("label", { class: "lb" }, "الأشخاص المعنيين"), pplBox),
        h("div", null, h("label", { class: "lb" }, "الضباط المشاركين"), offBox),
        h("div", null, h("label", { class: "lb" }, "التفاصيل"), body),
        h("div", { class: "row" },
            h("button", { class: "btn pri", onclick: save }, r.id ? "حفظ التعديلات" : "إنشاء التقرير"),
            r.id && ME.canDelete ? h("button", { class: "btn red", onclick: () => confirmModal(`تحذف التقرير #${r.id}؟`, async () => {
                if (await api("deleteReport", { id: r.id })) { toast("انحذف التقرير", "ok"); REP.sel = null; reload(); openReport(null, box, reload); }
            }) }, "حذف") : null)));
    if (!id) setTimeout(() => title.focus(), 50);
}

/* ================= أوامر القبض ================= */
let warClosed = false;
VIEWS.warrants = async () => {
    const list = (await api("listWarrants", { closed: warClosed })) || [];
    if (!warClosed) { COUNTS.warrants = list.length; renderNav(); }
    return h("div", { class: "col" },
        h("div", { class: "row" },
            h("div", { class: "tabs", style: "flex:1;margin:0" },
                h("div", { class: "tab" + (!warClosed ? " on" : ""), onclick: () => { warClosed = false; go("warrants"); } }, "الفعالة"),
                h("div", { class: "tab" + (warClosed ? " on" : ""), onclick: () => { warClosed = true; go("warrants"); } }, "المنفذة")),
            h("button", { class: "btn pri", onclick: () => warrantModal(null, () => go("warrants")) }, icon("plus"), "أمر قبض جديد")),
        list.length ? h("div", { class: "grid", style: "grid-template-columns:repeat(auto-fill,minmax(340px,1fr))" }, list.map((w) => h("div", { class: "card", style: Number(w.active) ? "border-color:rgba(255,77,109,.4)" : "" },
            h("div", { class: "row", style: "margin-bottom:8px" },
                h("span", { class: "ico " + (Number(w.active) ? "red" : "") }, icon("warrant")),
                h("div", { class: "t", style: "flex:1;cursor:pointer", onclick: () => go("citizens", w.citizenid) }, h("b", { style: "font-size:15px;display:block" }, w.name), h("small", { class: "dim" }, w.citizenid)),
                h("span", { class: "time" }, ago(w.ts))),
            h("div", { style: "margin-bottom:8px;line-height:1.7" }, w.reason),
            h("div", { class: "chips", style: "margin-bottom:8px" }, parse(w.charges).map((x) => h("span", { class: "tag gray" }, x))),
            h("small", { class: "dim", style: "display:block;margin-bottom:10px" }, "أصدره: " + (w.author || "") + (w.closed_by ? " • نفذه: " + w.closed_by : "")),
            h("div", { class: "row" },
                Number(w.active) ? h("button", { class: "btn green sm", onclick: async () => { if (await api("closeWarrant", { id: w.id })) { toast("تم تنفيذ أمر القبض", "ok"); go("warrants"); } } }, "تم التنفيذ") : null,
                h("button", { class: "btn sm", onclick: () => go("citizens", w.citizenid) }, "الملف"),
                ME.canDelete ? h("button", { class: "btn red sm", onclick: () => confirmModal("تحذف أمر القبض؟", async () => { if (await api("deleteWarrant", { id: w.id })) go("warrants"); }) }, "حذف") : null)))) : emptyBox(warClosed ? "ماكو أوامر منفذة" : "ماكو مطلوبين هسه", "warrant"));
};

/* ================= التعميمات ================= */
VIEWS.bolos = async () => {
    const list = (await api("listBolos")) || [];
    COUNTS.bolos = list.length; renderNav();
    return h("div", { class: "col" },
        h("div", { class: "row" }, h("div", { style: "flex:1" }),
            h("button", { class: "btn pri", onclick: () => boloModal({}, () => go("bolos")) }, icon("plus"), "تعميم جديد")),
        list.length ? h("div", { class: "grid", style: "grid-template-columns:repeat(auto-fill,minmax(300px,1fr))" }, list.map((b) => h("div", { class: "card", style: "border-color:rgba(255,169,77,.35)" },
            h("div", { class: "row", style: "margin-bottom:8px" },
                h("span", { class: "ico orange" }, icon(b.kind === "vehicle" ? "car" : "user")),
                h("div", { style: "flex:1" }, h("b", { style: "font-size:15px;display:block" }, b.title), h("small", { class: "dim" }, b.kind === "vehicle" ? "مركبة" : "شخص")),
                h("span", { class: "time" }, ago(b.ts))),
            b.plate ? h("div", { style: "display:inline-block;margin-bottom:8px;padding:3px 12px;border-radius:8px;background:#f1f5fb;color:#0a1a33;font-weight:800;letter-spacing:2px;direction:ltr;cursor:pointer", onclick: () => go("vehicles", b.plate) }, b.plate) : null,
            h("div", { style: "margin-bottom:8px;line-height:1.7;white-space:pre-wrap" }, b.description || ""),
            h("small", { class: "dim", style: "display:block;margin-bottom:10px" }, "بواسطة: " + (b.author || "")),
            h("button", { class: "btn green sm", onclick: async () => { if (await api("removeBolo", { id: b.id })) { toast("انشال التعميم", "ok"); go("bolos"); } } }, "إلغاء التعميم")))) : emptyBox("ماكو تعميمات فعالة", "bolo"));
};

/* ================= قانون العقوبات ================= */
function penalGrid(opts = {}) {
    const wrap = h("div");
    const draw = (q = "") => {
        wrap.replaceChildren();
        (CFG.penal || []).forEach((cat) => {
            const items = cat.items.filter((i) => !q || i.label.includes(q));
            if (!items.length) return;
            wrap.append(h("div", { class: "catH", style: `--c:${cat.color}` }, h("i"), cat.category, h("span", { class: "dim", style: "font-size:12px" }, `(${items.length})`)));
            wrap.append(h("div", { class: "pen" }, items.map((i) => {
                const on = opts.selected && opts.selected.has(i.id);
                return h("div", { class: "pi" + (opts.pick ? " pick" : "") + (on ? " on" : ""), style: `--c:${cat.color}`, onclick: opts.pick ? () => { opts.pick(i); draw(q); } : null },
                    opts.pick ? h("input", { type: "checkbox", checked: on, style: "accent-color:var(--blue);pointer-events:none" }) : null,
                    h("span", { class: "t" }, i.label),
                    h("span", { class: "v" }, h("b", null, money(i.fine)), i.jail ? h("span", null, i.jail + " شهر") : h("span", { class: "dim" }, "بدون سجن")));
            })));
        });
        if (!wrap.children.length) wrap.append(emptyBox("ماكو تهمة بهذا الاسم", "law"));
    };
    draw();
    wrap.redraw = draw;
    return wrap;
}
VIEWS.penal = () => {
    const grid = penalGrid();
    const inp = h("input", { class: "in", placeholder: "ابحث عن تهمة...", oninput: (e) => grid.redraw(e.target.value.trim()) });
    return h("div", { class: "col" }, h("div", { class: "search", style: "max-width:420px" }, icon("search"), inp), grid);
};

/* ================= الوحدات ================= */
VIEWS.units = async () => {
    const list = (await api("units")) || [];
    const statusOf = (id) => (CFG.statuses || []).find((s) => s.id === id) || { label: id, color: "#3ddc97" };
    if (!list.length) return emptyBox("ماكو أحد بالدوام", "units");
    return h("div", { class: "card" }, h("table", { class: "tb" },
        h("thead", null, h("tr", null, ["الكود", "الاسم", "الرتبة", "القسم", "الحالة", "ID"].map((x) => h("th", null, x)))),
        h("tbody", null, list.map((u) => {
            const s = statusOf(u.status);
            return h("tr", { class: u.cid === ME.cid ? "me" : "" },
                h("td", null, h("span", { class: "tag" + (u.callsign ? "" : " gray"), style: "direction:ltr" }, u.callsign || "—")),
                h("td", null, h("b", null, u.name), u.role ? h("span", { class: "tag", style: "margin-inline-start:6px;background:rgba(245,196,81,.18);color:var(--gold)" }, u.role) : null),
                h("td", null, u.rank),
                h("td", { class: "muted" }, u.job),
                h("td", null, h("span", { class: "dot", style: `--c:${s.color}` }), s.label),
                h("td", { class: "muted" }, u.id));
        }))));
};

/* ================= النوافذ ================= */
function modal(title, body, foot, wide) {
    const m = $("#modal"), box = $("#mBox");
    box.className = "mBox" + (wide ? " wide" : "");
    box.replaceChildren(
        h("div", { class: "mHead" }, h("b", null, title), h("button", { class: "x", onclick: closeModal }, "✕")),
        h("div", { class: "mBody" }, body),
        foot ? h("div", { class: "mFoot" }, foot) : null);
    m.classList.remove("hidden");
}
function closeModal() { $("#modal").classList.add("hidden"); $("#mBox").replaceChildren(); }
$("#modal").addEventListener("mousedown", (e) => { if (e.target.id === "modal") closeModal(); });

function confirmModal(text, yes) {
    modal("تأكيد", h("div", { style: "font-size:15px" }, text), [
        h("button", { class: "btn red", onclick: () => { closeModal(); yes(); } }, "نعم"),
        h("button", { class: "btn", onclick: closeModal }, "لا")]);
}

function citizenPicker(cb) {
    const list = h("div", { style: "min-height:200px" }, emptyBox("اكتب اسم أو رقم هوية", "user"));
    const inp = h("input", { class: "in", placeholder: "ابحث عن مواطن...", oninput: debounce(async (e) => {
        const q = e.target.value.trim();
        if (!q) return list.replaceChildren(emptyBox("اكتب اسم أو رقم هوية", "user"));
        list.replaceChildren(loading());
        const r = (await api("searchCitizens", { q })) || [];
        list.replaceChildren(...(r.length ? r.map((c) => h("div", { class: "li", onclick: () => { closeModal(); cb(c); } },
            avatar(c.name, c.image), h("div", { class: "t" }, h("b", null, c.name), h("small", null, c.cid)), c.wanted ? h("span", { class: "tag red" }, "مطلوب") : null)) : [emptyBox("ماكو نتائج")]));
    }, 300) });
    modal("اختيار مواطن", h("div", { class: "col" }, h("div", { class: "search" }, icon("search"), inp), list));
    setTimeout(() => inp.focus(), 50);
}

async function unitPicker(cb) {
    const list = (await api("units")) || [];
    modal("اختيار ضابط", list.length ? h("div", null, list.map((u) => h("div", { class: "li", onclick: () => { closeModal(); cb(u); } },
        avatar(u.name), h("div", { class: "t" }, h("b", null, u.name), h("small", null, u.rank)), h("span", { class: "tag" }, u.callsign || "—")))) : emptyBox("ماكو أحد بالدوام", "units"));
}

function imageModal(cur, cb) {
    const prev = h("div", { class: "photo", style: "margin:0 auto;cursor:default" });
    const inp = h("input", { class: "in", placeholder: "https://...", value: cur, style: "direction:ltr", oninput: () => draw() });
    const draw = () => { prev.replaceChildren(); if (/^https?:\/\//.test(inp.value)) prev.append(h("img", { src: inp.value, onerror: (e) => e.target.remove() })); };
    draw();
    modal("صورة المواطن", h("div", { class: "col" }, prev, h("label", { class: "lb" }, "رابط الصورة (Imgur / Discord ...)"), inp), [
        h("button", { class: "btn pri", onclick: () => { const v = inp.value.trim(); if (v && !/^https?:\/\//.test(v)) return toast("الرابط لازم يبدي بـ https://", "err"); closeModal(); cb(v); } }, "حفظ"),
        h("button", { class: "btn red", onclick: () => { closeModal(); cb(""); } }, "مسح الصورة")]);
}

function sentenceModal(p, done) {
    const sel = new Set();
    const totals = h("div", { class: "total" });
    const fine = h("input", { type: "checkbox", checked: true });
    const jail = h("input", { type: "checkbox", checked: !!p.online });
    const calc = () => {
        let f = 0, j = 0;
        (CFG.penal || []).forEach((c) => c.items.forEach((i) => { if (sel.has(i.id)) { f += i.fine; j += i.jail; } }));
        totals.replaceChildren(
            h("span", null, h("small", null, "التهم"), h("b", { style: "font-size:18px" }, sel.size)),
            h("span", null, h("small", null, "الغرامة"), h("b", { class: "f" }, money(f))),
            h("span", null, h("small", null, "السجن"), h("b", { class: "j" }, j + " شهر")));
    };
    const grid = penalGrid({ selected: sel, pick: (i) => { sel.has(i.id) ? sel.delete(i.id) : sel.add(i.id); calc(); } });
    const inp = h("input", { class: "in", placeholder: "ابحث عن تهمة...", oninput: (e) => grid.redraw(e.target.value.trim()) });
    calc();
    modal("حكم على: " + p.name, h("div", { class: "col" }, h("div", { class: "search" }, icon("search"), inp), grid), [
        totals,
        h("label", { class: "chk" }, fine, "سحب الغرامة"),
        h("label", { class: "chk", title: p.online ? "لازم يكون يمك" : "غير متصل" }, jail, "إرسال للسجن"),
        h("button", { class: "btn pri", onclick: async () => {
            if (!sel.size) return toast("اختار تهمة وحدة على الأقل", "err");
            const r = await api("sentence", { cid: p.cid, charges: [...sel], doFine: fine.checked, doJail: jail.checked });
            if (!r) return;
            if (!r.ok) return toast(r.msg, "err");
            closeModal(); toast(r.msg, "ok"); done && done();
        } }, icon("gavel"), "تنفيذ الحكم")], true);
}

function warrantModal(person, done) {
    let who = person;
    const sel = new Set();
    const whoBox = h("div");
    const drawWho = () => whoBox.replaceChildren(who
        ? h("div", { class: "li on" }, avatar(who.name), h("div", { class: "t" }, h("b", null, who.name), h("small", null, who.cid)), h("button", { class: "btn sm", onclick: () => citizenPickerInline() }, "تغيير"))
        : h("button", { class: "btn", onclick: () => citizenPickerInline() }, icon("user"), "اختيار المطلوب"));
    const reason = h("textarea", { class: "in", style: "min-height:80px", placeholder: "سبب أمر القبض..." });
    const grid = penalGrid({ selected: sel, pick: (i) => (sel.has(i.id) ? sel.delete(i.id) : sel.add(i.id)) });
    const body = h("div", { class: "col" }, h("label", { class: "lb" }, "المطلوب"), whoBox, h("label", { class: "lb" }, "السبب"), reason, h("label", { class: "lb" }, "التهم (اختياري)"), grid);
    const foot = [h("button", { class: "btn red", onclick: async () => {
        if (!who) return toast("اختار المطلوب", "err");
        const r = await api("createWarrant", { cid: who.cid, reason: reason.value, charges: [...sel] });
        if (!r) return;
        if (!r.ok) return toast(r.msg, "err");
        closeModal(); toast("انصدر أمر القبض", "ok"); done && done();
    } }, icon("warrant"), "إصدار أمر القبض")];
    const show = () => { drawWho(); modal("أمر قبض جديد", body, foot, true); };
    const citizenPickerInline = () => citizenPicker((c) => { who = c; show(); });
    show();
}

function boloModal(pre, done) {
    let kind = pre.kind || "person";
    const title = h("input", { class: "in", placeholder: "مثال: شخص لابس أسود هارب من بنك...", value: pre.title || "" });
    const plate = h("input", { class: "in", placeholder: "رقم اللوحة", value: pre.plate || "", style: "direction:ltr;text-align:right;text-transform:uppercase" });
    const plateRow = h("div", null, h("label", { class: "lb" }, "رقم اللوحة"), plate);
    const desc = h("textarea", { class: "in", style: "min-height:100px", placeholder: "الأوصاف، آخر مكان شوهد بيه، الاتجاه..." });
    const kb = h("div", { class: "tabs" });
    const drawKind = () => {
        kb.replaceChildren(
            h("div", { class: "tab" + (kind === "person" ? " on" : ""), onclick: () => { kind = "person"; drawKind(); } }, "شخص"),
            h("div", { class: "tab" + (kind === "vehicle" ? " on" : ""), onclick: () => { kind = "vehicle"; drawKind(); } }, "مركبة"));
        plateRow.classList.toggle("hidden", kind !== "vehicle");
    };
    drawKind();
    modal("تعميم جديد", h("div", { class: "col" }, kb, h("label", { class: "lb" }, "العنوان"), title, plateRow, h("label", { class: "lb" }, "التفاصيل"), desc), [
        h("button", { class: "btn pri", onclick: async () => {
            const r = await api("createBolo", { kind, title: title.value, plate: plate.value, description: desc.value });
            if (!r) return;
            if (!r.ok) return toast(r.msg, "err");
            closeModal(); toast("انرسل التعميم لكل الوحدات", "ok"); done && done();
        } }, icon("bolo"), "نشر التعميم")]);
}

/* ================= الضابط ================= */
function renderMe() {
    $("#jobLabel").textContent = ME.job || "الأمن العام";
    $("#meName").textContent = ME.name || "";
    $("#meRank").textContent = ME.rank || "";
    $("#meAv").textContent = initial(ME.name);
    $("#meCs").textContent = ME.callsign || "كود؟";
    const s = $("#meStatus");
    s.replaceChildren(...(CFG.statuses || []).map((x) => h("option", { value: x.id }, "● " + x.label)));
    s.value = ME.status || "available";
    paintStatus();
}
function paintStatus() {
    const s = (CFG.statuses || []).find((x) => x.id === $("#meStatus").value);
    $("#meStatus").style.color = s ? s.color : "";
}
$("#meStatus").addEventListener("change", async (e) => {
    paintStatus();
    if (await api("setStatus", { status: e.target.value })) { ME.status = e.target.value; toast("تغيرت حالتك", "ok"); if (PAGE === "units" || PAGE === "dash") go(PAGE); }
});
$("#meCs").addEventListener("click", () => {
    const inp = h("input", { class: "in", value: ME.callsign || "", maxlength: 10, style: "direction:ltr;text-align:center;font-size:20px;font-weight:800", placeholder: "مثال: 101" });
    modal("كود الوحدة", inp, [h("button", { class: "btn pri", onclick: async () => {
        const v = inp.value.trim();
        if (!v) return;
        if (await api("setCallsign", { callsign: v })) { ME.callsign = v; renderMe(); closeModal(); toast("تغير الكود إلى " + v, "ok"); }
    } }, "حفظ")]);
    setTimeout(() => inp.focus(), 50);
});

/* ================= فتح / إغلاق ================= */
function closeMdt() {
    closeModal();
    $("#mdt").classList.add("hidden");
    if (IN_GAME) fetch(`https://${RES}/close`, { method: "POST", body: "{}" }).catch(() => {});
}
$("#closeBtn").onclick = closeMdt;
window.addEventListener("keydown", (e) => {
    if (e.key !== "Escape" || $("#mdt").classList.contains("hidden")) return;
    if (!$("#modal").classList.contains("hidden")) closeModal(); else closeMdt();
});

function tick() {
    const d = new Date();
    $("#clock").textContent = d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
    $("#date").textContent = d.toLocaleDateString("ar-IQ-u-nu-latn", { weekday: "long", day: "numeric", month: "long" });
}
setInterval(tick, 10000); tick();

function openMdt(data) {
    ME = data.me || {};
    CFG = data;
    renderMe();
    $("#mdt").classList.remove("hidden");
    go(PAGE || "dash");
}

window.addEventListener("message", ({ data: m }) => {
    if (!m) return;
    if (m.action === "open") openMdt(m.data);
    else if (m.action === "close") { closeModal(); $("#mdt").classList.add("hidden"); }
    else if (m.action === "dispatch" && m.alert) {
        if (PAGE === "dispatch" && DSP.refresh) DSP.refresh(m.alert);
        else { COUNTS.dispatch = (COUNTS.dispatch || 0) + 1; renderNav(); toast(`🚨 ${m.alert.code} ${m.alert.title}`, "err"); }
    }
});

/* ================= معاينة خارج اللعبة ================= */
let MOCK = () => null;
let MOCK_NUI = (n, d) => {
    if (n === "mypos") return { x: 430, y: -980, z: 30 };
    if (n === "streets") return d.map(() => ({ street: "Vespucci Blvd / Sinner St", zone: "Mission Row" }));
    return true;
};
if (!IN_GAME) {
    const now = Math.floor(Date.now() / 1000);
    const penal = [
        { category: "مخالفات مرورية", color: "#3bc9db", items: [{ id: "t1", label: "تجاوز السرعة المحددة", fine: 500, jail: 0 }, { id: "t3", label: "قيادة بدون رخصة", fine: 1500, jail: 0 }, { id: "t4", label: "قيادة متهورة", fine: 2000, jail: 5 }] },
        { category: "جنح", color: "#ffa94d", items: [{ id: "m2", label: "إهانة موظف حكومي", fine: 1500, jail: 5 }, { id: "m7", label: "مقاومة الاعتقال", fine: 5000, jail: 20 }] },
        { category: "جنايات", color: "#ff4d6d", items: [{ id: "f2", label: "حمل سلاح بدون رخصة", fine: 10000, jail: 30 }, { id: "f5", label: "سطو على بنك", fine: 40000, jail: 80 }, { id: "f9", label: "قتل عمد", fine: 50000, jail: 120 }] },
    ];
    const units = [
        { id: 1, cid: "ME1", name: "Stone Ali", rank: "لواء ركن", job: "الأمن العام", callsign: "101", status: "patrol" },
        { id: 4, cid: "U2", name: "حيدر كريم", rank: "عقيد", job: "الأمن العام", callsign: "205", status: "available" },
        { id: 9, cid: "U3", name: "علي حسين", rank: "نقيب", job: "Military", callsign: null, status: "scene" },
    ];
    const cits = [
        { cid: "ABC12345", name: "مصطفى جبار", phone: "0770123456", wanted: true, tags: ["خطر"] },
        { cid: "XYZ98765", name: "سارة أحمد", phone: "0780555111", wanted: false, tags: [] },
    ];
    const DB = { cases: [{ id: 1, citizenid: "XYZ98765", name: "سارة أحمد", charges: '["قيادة متهورة"]', fine: 2000, jail: 5, fined: 1, jailed: 1, description: "انمسكت تسوق بسرعة عالية بشارع فاينوود.", author: "عقيد حيدر كريم", ts: now - 7200 }], reports: [{ id: 3, title: "سطو مسلح على محل 24/7", type: "سرقة", author: "نقيب علي حسين", ts: now - 1800, body: "تم الإبلاغ عن سطو مسلح...", involved: [{ cid: "ABC12345", name: "مصطفى جبار", role: "متهم" }], officers: [{ cid: "U3", name: "نقيب علي حسين" }] }], warrants: [{ id: 1, citizenid: "ABC12345", name: "مصطفى جبار", reason: "سطو مسلح على محل 24/7 وهروب", charges: '["سطو مسلح على محل","مقاومة الاعتقال"]', author: "نقيب علي حسين", active: 1, ts: now - 3600 }], bolos: [{ id: 1, kind: "vehicle", title: "سلطان أسود هارب", plate: "46EEK572", description: "شوهد آخر مرة بشارع فاينوود", author: "عقيد حيدر كريم", ts: now - 600 }] };
    MOCK = (n, d) => {
        switch (n) {
            case "dashboard": return { counts: { units: 3, warrants: DB.warrants.filter((w) => w.active).length, bolos: DB.bolos.length, reports: DB.reports.length, convictions: 2 }, units, reports: DB.reports, warrants: DB.warrants.filter((w) => w.active), bolos: DB.bolos };
            case "searchCitizens": return cits.filter((c) => c.name.includes(d.q) || c.cid.includes(d.q.toUpperCase()));
            case "getProfile": { const c = cits.find((x) => x.cid === d.cid) || cits[0]; return { ...c, dob: "1995-04-12", gender: 0, nationality: "عراقي", job: "Civilian", jobGrade: "Freelancer", online: true, serverId: 7, injail: 0, fingerprint: "ak93jd02", bloodtype: "O+", image: "", notes: "", licenses: { driver: true, weapon: false, business: false }, vehicles: [{ plate: "46EEK572", label: "Declasse Sultan", state: 0 }], convictions: [{ id: 1, charges: '["قيادة متهورة","تجاوز السرعة المحددة"]', fine: 2500, jail: 5, fined: 1, jailed: 0, note: "ما انسجن: بعيد عن الضابط", author: "عقيد حيدر كريم", ts: now - 86400 * 2 }], warrants: DB.warrants.filter((w) => w.citizenid === c.cid), reports: DB.reports };
            }
            case "searchVehicles": return [{ plate: "46EEK572", label: "Declasse Sultan", owner: "مصطفى جبار", stolen: true }];
            case "getVehicle": return { plate: d.plate, label: "Declasse Sultan", model: "sultan", owner: "مصطفى جبار", ownerCid: "ABC12345", state: 0, garage: "pillbox", engine: 92, body: 78, stolen: true, notes: "", bolos: DB.bolos.filter((b) => b.plate === d.plate) };
            case "listReports": return DB.reports;
            case "getReport": return DB.reports.find((r) => r.id === d.id);
            case "saveReport": if (!d.title) return { ok: false, msg: "اكتب عنوان التقرير" }; if (!d.id) { d.id = DB.reports.length + 10; DB.reports.unshift({ ...d, author: "لواء ركن Stone Ali", ts: now }); } return { ok: true, id: d.id };
            case "listWarrants": return DB.warrants.filter((w) => !!w.active === !d.closed);
            case "createWarrant": DB.warrants.unshift({ id: Date.now(), citizenid: d.cid, name: cits.find((c) => c.cid === d.cid)?.name, reason: d.reason, charges: "[]", author: "لواء ركن Stone Ali", active: 1, ts: now }); return { ok: true };
            case "closeWarrant": DB.warrants.find((w) => w.id === d.id).active = 0; return true;
            case "listBolos": return DB.bolos;
            case "createBolo": DB.bolos.unshift({ id: Date.now(), ...d, author: "لواء ركن Stone Ali", ts: now }); return { ok: true };
            case "removeBolo": DB.bolos = DB.bolos.filter((b) => b.id !== d.id); return true;
            case "sentence": { const id = (DB.cases[0]?.id || 0) + 1; DB.cases.unshift({ id, citizenid: d.cid, name: cits.find((c) => c.cid === d.cid)?.name || "متهم", charges: JSON.stringify(d.extra ? [d.extra] : ["قيادة متهورة"]), fine: d.fine, jail: d.jail, fined: d.doFine ? 1 : 0, jailed: d.doJail ? 1 : 0, description: d.description, author: "لواء ركن Stone Ali", ts: now }); return { ok: true, msg: `انسجلت القضية #${id}`, id }; }
            case "listCases": return DB.cases.filter((c) => !d.q || String(c.id) === d.q || (c.name || "").includes(d.q));
            case "nearby": return [{ cid: "ABC12345", name: "مصطفى جبار", id: 7, dist: 2.4, cuffed: true, injail: 0 }];
            case "units": return units;
            case "dispatch": return { list: [
                { id: 5, type: "bank", code: "10-90", title: "سرقة بنك", color: "#ff2e57", priority: 3, coords: { x: 150, y: -1040, z: 29 }, time: now - 60, responders: ["[205] عقيد حيدر كريم"] },
                { id: 4, type: "shooting", code: "10-71", title: "إطلاق نار", color: "#ff4d6d", priority: 2, coords: { x: 100, y: -1940, z: 20 }, time: now - 240, gender: "ذكر", details: [["من داخل", "مركبة"]], vehicle: { model: "Sultan", plate: "46EEK572" }, responders: [] },
                { id: 3, type: "prison", code: "10-98", title: "هروب من السجن", color: "#ff2e57", priority: 3, coords: { x: 1693, y: 2569, z: 45 }, time: now - 900, responders: [] },
                { id: 2, type: "suspicious", code: "10-37", title: "حركة مشبوهة", color: "#f5c451", priority: 1, coords: { x: 1960, y: 3740, z: 32 }, time: now - 1500, message: "شخص يوجه سلاح على مواطن", responders: [] },
                { id: 1, type: "cartheft", code: "10-60", title: "سرقة سيارة", color: "#ffa94d", priority: 1, coords: { x: -150, y: 6350, z: 31 }, time: now - 3000, responders: [] },
            ] };
            default: return true;
        }
    };
    document.body.style.background = "#24384f";
    openMdt({ me: { name: "Stone Ali", rank: "لواء ركن", callsign: "101", cid: "ME1", job: "الأمن العام", canDelete: true, status: "patrol" }, penal,
        statuses: [{ id: "available", label: "متاح", color: "#3ddc97" }, { id: "patrol", label: "بدورية", color: "#2f8cff" }, { id: "busy", label: "مشغول", color: "#ffa94d" }, { id: "scene", label: "بموقع حادث", color: "#ff4d6d" }],
        licenses: [{ id: "driver", label: "رخصة سياقة" }, { id: "weapon", label: "رخصة سلاح" }, { id: "business", label: "رخصة تجارية" }],
        tags: ["خطر", "مسلح", "مطلوب", "عصابة", "مراقبة"], reportTypes: ["حادث مروري", "سرقة", "اعتداء", "أخرى"] });
}
