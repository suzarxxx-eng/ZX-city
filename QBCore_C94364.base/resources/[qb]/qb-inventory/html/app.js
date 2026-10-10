/* =========================================================
   الانفنتوري العربي - واجهة qb-inventory
   30 خانة + 5 خانات استخدام سريع - وزن 150 كغم
   ========================================================= */
const $ = (s) => document.querySelector(s);
const RES = typeof GetParentResourceName === "function" ? GetParentResourceName() : "qb-inventory";

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
    })
        .then((r) => r.text())
        .then((t) => {
            try { return JSON.parse(t); } catch (e) { return t; }
        })
        .catch(() => null);
}

const S = {
    open: false,
    slots: 35, hot: 5, maxW: 150000,
    dropSlots: 50, dropW: 1000000,
    openKey: "TAB",
    player: {},
    other: null, // { name, label, kind, maxW, slots, items }
    sel: null,   // { inv, slot }
    press: null,
    drag: null,
    attach: null,
};

const CIRC = 263.9;

/* ---------------- أدوات ---------------- */
const kg = (g) => {
    const v = (Number(g) || 0) / 1000;
    return v >= 100 ? v.toFixed(0) : +v.toFixed(2) + "";
};
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const range = (a, b) => { const r = []; for (let i = a; i <= b; i++) r.push(i); return r; };

function toMap(list) {
    const out = {};
    if (!list) return out;
    const arr = Array.isArray(list) ? list : Object.values(list);
    arr.forEach((it) => { if (it && it.slot) out[it.slot] = it; });
    return out;
}

function invItems(inv) { return inv === "player" ? S.player : (S.other ? S.other.items : {}); }
function invMax(inv) { return inv === "player" ? S.maxW : (S.other ? S.other.maxW : 0); }
function invSlots(inv) { return inv === "player" ? S.slots : (S.other ? S.other.slots : 0); }
function invName(inv) { return inv === "player" ? "player" : (S.other ? S.other.name : ""); }
function weightOf(items) {
    let w = 0;
    for (const k in items) { const it = items[k]; if (it) w += (Number(it.weight) || 0) * (Number(it.amount) || 0); }
    return w;
}
function fits(inv, addW, removeW = 0) {
    return weightOf(invItems(inv)) - removeW + addW <= invMax(inv) + 0.001;
}
function getItem(inv, slot) { return invItems(inv)[slot] || null; }
const isShop = () => !!(S.other && S.other.kind === "shop");
const canUse = (it) => !!it; // OG: كل الأغراض تنستعمل

function kindOf(name) {
    name = String(name || "");
    if (name.startsWith("shop-")) return "shop";
    if (name.startsWith("drop-")) return "drop";
    if (name.startsWith("trunk-")) return "trunk";
    if (name.startsWith("glovebox-")) return "glovebox";
    if (name.startsWith("otherplayer-")) return "player";
    return "stash";
}

function prettyLabel(name, label) {
    const k = kindOf(name);
    if (k === "drop") return "الأرض";
    if (k === "trunk") return "صندوق السيارة";
    if (k === "glovebox") return "درج السيارة";
    if (k === "player") return "تفتيش: " + (label || "لاعب");
    if (label && label !== name) return label;
    return k === "shop" ? "المتجر" : "المخزن";
}

function tagLabel(name) {
    const k = kindOf(name);
    if (k === "trunk") return "لوحة " + name.slice(6).trim();
    if (k === "glovebox") return "لوحة " + name.slice(9).trim();
    if (k === "shop") return "متجر";
    if (k === "drop") return "أغراض مرمية";
    if (k === "player") return "حقيبة لاعب";
    return "خزنة";
}

/* ---------------- الأصوات والتنبيهات ---------------- */
function toast(text, kind = "info") {
    const t = document.createElement("div");
    t.className = "toast " + kind;
    t.textContent = text;
    $("#toasts").appendChild(t);
    setTimeout(() => t.classList.add("out"), 2600);
    setTimeout(() => t.remove(), 3000);
}

function fail(inv, slot, msg) {
    post("PlayDropFail");
    if (msg) toast(msg, "error");
    const sec = inv === "player" ? "#playerPanel" : "#otherPanel";
    const el = document.querySelector(`${sec} .slot[data-slot="${slot}"]`);
    if (el) {
        el.classList.remove("error");
        void el.offsetWidth;
        el.classList.add("error");
        setTimeout(() => el.classList.remove("error"), 700);
    }
}

/* ---------------- رسم الخانات ---------------- */
function iconNode(it, cls = "ico") {
    const box = document.createElement("div");
    box.className = cls;
    const emoji = () => { box.textContent = "📦"; };
    if (it && it.image) {
        const img = new Image();
        img.src = "images/" + it.image;
        img.alt = "";
        img.onerror = () => { img.remove(); emoji(); };
        box.appendChild(img);
    } else emoji();
    return box;
}

function qualityBar(it) {
    if (!it.info || typeof it.info !== "object" || it.info.quality === undefined || it.info.quality === null) return null;
    const q = clamp(Number(it.info.quality) || 0, 0, 100);
    const wrap = document.createElement("i");
    wrap.className = "q";
    const fill = document.createElement("i");
    fill.style.width = q + "%";
    if (q <= 25) fill.className = "low";
    else if (q <= 75) fill.className = "mid";
    wrap.appendChild(fill);
    return wrap;
}

function buildSlot(inv, slot, it, opts = {}) {
    const el = document.createElement("div");
    el.className = "slot";
    if (inv) { el.dataset.inv = inv; el.dataset.slot = slot; }
    if (opts.key) {
        el.classList.add("hk");
        const k = document.createElement("b");
        k.className = "key";
        k.textContent = opts.key;
        el.appendChild(k);
    }
    if (it) {
        el.classList.add("full");
        el.appendChild(iconNode(it));
        const nm = document.createElement("span");
        nm.className = "nm";
        nm.textContent = it.label || it.name;
        el.appendChild(nm);
        const c = document.createElement("b");
        c.className = "cnt";
        c.textContent = "x" + it.amount;
        el.appendChild(c);
        if (opts.price && it.price !== undefined) {
            const p = document.createElement("b");
            p.className = "price";
            p.textContent = "$" + it.price;
            el.appendChild(p);
        }
        const q = qualityBar(it);
        if (q) el.appendChild(q);
    }
    if (S.sel && S.sel.inv === inv && S.sel.slot === slot) el.classList.add("selected");
    if (S.drag && S.drag.inv === inv && S.drag.slot === slot) el.classList.add("src");
    return el;
}

function setBar(bar, ratio) {
    bar.style.width = Math.min(ratio, 1) * 100 + "%";
    bar.classList.toggle("warn", ratio >= 0.75 && ratio < 1);
    bar.classList.toggle("full", ratio >= 0.999);
}

function renderPlayer() {
    const grid = $("#pGrid"), hot = $("#pHot");
    grid.replaceChildren();
    hot.replaceChildren();
    for (let i = S.hot + 1; i <= S.slots; i++) grid.appendChild(buildSlot("player", i, S.player[i]));
    for (let i = 1; i <= S.hot; i++) hot.appendChild(buildSlot("player", i, S.player[i], { key: i }));

    const w = weightOf(S.player);
    const ratio = S.maxW ? w / S.maxW : 0;
    $("#pW").textContent = kg(w);
    $("#pMax").textContent = kg(S.maxW);
    $("#pTag").textContent = (S.slots - S.hot) + " خانة";
    setBar($("#pBar"), ratio);

    $("#gW").textContent = kg(w);
    $("#gMax").textContent = kg(S.maxW);
    const ring = $("#ring");
    ring.style.strokeDashoffset = CIRC * (1 - Math.min(ratio, 1));
    ring.classList.toggle("warn", ratio >= 0.75 && ratio < 1);
    ring.classList.toggle("full", ratio >= 0.999);
}

function renderOther() {
    const panel = $("#otherPanel");
    if (!S.other) { panel.classList.add("hidden"); return; }
    panel.classList.remove("hidden");
    const o = S.other;
    $("#oName").textContent = prettyLabel(o.name, o.label);
    $("#oTag").textContent = tagLabel(o.name);
    const shop = o.kind === "shop";
    $("#oWt").classList.toggle("hidden", shop);
    $("#oBarBox").classList.toggle("hidden", shop);
    if (!shop) {
        const w = weightOf(o.items);
        $("#oW").textContent = kg(w);
        $("#oMax").textContent = kg(o.maxW);
        setBar($("#oBar"), o.maxW ? w / o.maxW : 0);
    }
    const grid = $("#oGrid");
    const top = grid.scrollTop;
    grid.replaceChildren();
    for (let i = 1; i <= o.slots; i++) grid.appendChild(buildSlot("other", i, o.items[i], { price: shop }));
    grid.scrollTop = top;
}

/* ---------------- التفاصيل ---------------- */
const INFO_LABELS = {
    serie: "الرقم التسلسلي", quality: "الجودة", ammo: "الذخيرة", citizenid: "رقم المواطن",
    firstname: "الاسم", lastname: "اللقب", birthdate: "تاريخ الميلاد", gender: "الجنس",
    nationality: "الجنسية", type: "النوع", worth: "القيمة", uses: "مرات الاستخدام",
    attachments: "الملحقات", plate: "اللوحة", model: "الموديل", label: "الاسم",
    tint: "اللون", job: "الوظيفة", name: "الاسم", health: "الصحة",
};
const HIDDEN_INFO = ["description", "display", "url", "costs"];

function infoValue(key, val) {
    if (key === "quality") return Math.round(Number(val) || 0) + "%";
    if (key === "gender") return Number(val) === 0 ? "ذكر" : Number(val) === 1 ? "أنثى" : String(val);
    if (key === "worth") return "$" + val;
    if (key === "attachments") return Array.isArray(val) ? String(val.length) : Object.keys(val || {}).length + "";
    if (val === true) return "نعم";
    if (val === false) return "لا";
    if (typeof val === "object") return null;
    return String(val);
}

function row(dl, k, v) {
    const d = document.createElement("div");
    const dt = document.createElement("dt");
    const dd = document.createElement("dd");
    dt.textContent = k;
    dd.textContent = v;
    d.append(dt, dd);
    dl.appendChild(d);
}

function button(label, cls, fn) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    if (cls) b.className = cls;
    b.onclick = fn;
    return b;
}

function getAmount() {
    const it = S.sel && getItem(S.sel.inv, S.sel.slot);
    if (!it) return 1;
    const v = parseInt($("#amt").value, 10);
    return clamp(isNaN(v) ? 1 : v, 1, it.amount);
}

function amountFor(inv, slot, fallbackAll = true) {
    const it = getItem(inv, slot);
    if (!it) return 1;
    if (S.sel && S.sel.inv === inv && S.sel.slot === slot) return getAmount();
    return fallbackAll ? it.amount : 1;
}

function renderDetail() {
    const box = $("#detail");
    if (S.sel && !getItem(S.sel.inv, S.sel.slot)) S.sel = null;
    box.classList.toggle("empty", !S.sel);
    if (!S.sel) return;
    const { inv, slot } = S.sel;
    const it = getItem(inv, slot);
    const shop = inv === "other" && isShop();

    $("#dIcon").replaceChildren(iconNode(it, "ico"));
    $("#dName").textContent = it.label || it.name;
    const desc = (it.info && typeof it.info === "object" && it.info.description) || it.description || "";
    $("#dDesc").textContent = desc;

    const dl = $("#dList");
    dl.replaceChildren();
    if (shop) {
        row(dl, "السعر", "$" + it.price);
        row(dl, "المتوفر", it.amount);
        row(dl, "وزن الحبة", kg(it.weight) + " كغم");
    } else {
        row(dl, "العدد", it.amount);
        row(dl, "وزن الحبة", kg(it.weight) + " كغم");
        row(dl, "الوزن الكلي", kg((it.weight || 0) * it.amount) + " كغم");
    }
    if (it.info && typeof it.info === "object" && it.info.display !== false) {
        for (const [k, v] of Object.entries(it.info)) {
            if (HIDDEN_INFO.includes(k) || v === null || v === undefined || v === "") continue;
            const val = infoValue(k, v);
            if (val !== null) row(dl, INFO_LABELS[k] || k, val);
        }
    }

    const a = $("#amt");
    a.max = it.amount;
    if (!(+a.value >= 1)) a.value = shop ? 1 : it.amount;
    if (+a.value > it.amount) a.value = it.amount;
    $("#amountBox").classList.toggle("hidden", it.amount <= 1 && !shop);

    const act = $("#actions");
    act.replaceChildren();
    if (shop) {
        act.appendChild(button("شراء", "primary", () => buy(slot, getAmount())));
    } else if (inv === "player") {
        if (canUse(it)) act.appendChild(button("استخدام", "primary", () => useItem(slot)));
        if (S.other) act.appendChild(button("نقل إلى " + prettyLabel(S.other.name, S.other.label), "wide", () => quickMove("player", slot, getAmount())));
        act.appendChild(button("إعطاء لأقرب لاعب", "", () => giveItem(slot, getAmount())));
        if (!S.other || S.other.kind === "drop")
            act.appendChild(button("رمي على الأرض", "danger", () => dropToGround(slot, getAmount())));
        if (it.amount > 1) act.appendChild(button("تقسيم", "", () => splitItem("player", slot, getAmount())));
        if (it.type === "weapon") {
            act.appendChild(button("الملحقات", "", () => openAttachments(slot)));
            if (it.info && it.info.serie) act.appendChild(button("نسخ الرقم التسلسلي", "", () => copyText(it.info.serie)));
        }
    } else {
        act.appendChild(button("نقل إلى الحقيبة", "primary", () => quickMove("other", slot, getAmount())));
        if (it.amount > 1) act.appendChild(button("تقسيم", "wide", () => splitItem("other", slot, getAmount())));
    }
    // حتى يكون عدد الأزرار متناسق
    const plain = [...act.children].filter((b) => !b.classList.contains("primary") && !b.classList.contains("wide"));
    if (plain.length % 2 === 1) plain[plain.length - 1].classList.add("wide");
}

function renderHint() {
    let t;
    if (isShop()) t = "اسحب الغرض إلى حقيبتك أو كليك يمين للشراء • حدد الكمية من اللوحة";
    else if (S.other) t = "اسحب للنقل • كليك يمين للنقل السريع • Shift + كليك للتقسيم";
    else t = "اسحب الغرض لنقله أو دمجه • نقرتين أو كليك يمين للاستخدام • Shift + كليك للتقسيم";
    $("#hint").textContent = t;
}

function fit() {
    const app = $("#app");
    app.style.transform = "none";
    const w = app.offsetWidth, h = app.offsetHeight;
    const k = Math.min(1, (window.innerWidth - 32) / w, (window.innerHeight - 32) / h);
    app.style.transform = k < 1 ? `scale(${k})` : "none";
    S.scale = k;
}

function render() {
    if (!S.open) return;
    renderPlayer();
    renderOther();
    renderDetail();
    renderHint();
    fit();
}

// التحديد بدون إعادة رسم الخانات (حتى تبقى النقرات والسحب سلسة)
function select(inv, slot) {
    const it = getItem(inv, slot);
    const same = S.sel && S.sel.inv === inv && S.sel.slot === slot;
    S.sel = it ? { inv, slot } : null;
    if (it && !same) $("#amt").value = inv === "other" && isShop() ? 1 : it.amount;
    document.querySelectorAll(".slot.selected").forEach((x) => x.classList.remove("selected"));
    if (S.sel) {
        const sec = inv === "player" ? "#playerPanel" : "#otherPanel";
        const el = document.querySelector(`${sec} .slot[data-slot="${slot}"]`);
        if (el) el.classList.add("selected");
    }
    renderDetail();
    fit();
}

function doubleAction(inv, slot) {
    if (!getItem(inv, slot)) return;
    if (inv === "player") useItem(slot);
    else if (isShop()) buy(slot, amountFor(inv, slot, false));
    else quickMove(inv, slot, amountFor(inv, slot));
}

/* ---------------- العمليات ---------------- */
function sendMove(fromInv, toInv, fromSlot, toSlot, fromAmount, toAmount) {
    post("SetInventoryData", {
        fromInventory: invName(fromInv),
        toInventory: invName(toInv),
        fromSlot: Number(fromSlot),
        toSlot: Number(toSlot),
        fromAmount: Math.max(0, Number(fromAmount) || 0),
        toAmount: Number(toAmount),
    });
}

function moveItem(fromInv, fromSlot, toInv, toSlot, amount) {
    fromSlot = Number(fromSlot); toSlot = Number(toSlot);
    if (fromInv === toInv && fromSlot === toSlot) return;
    if (toInv === "other" && !S.other) return;

    if (isShop()) {
        if (fromInv === "other") { if (toInv === "player") buy(fromSlot, amount); return; }
        if (toInv === "other") return fail(fromInv, fromSlot, "لا يمكنك وضع أغراض داخل المتجر");
    }

    const src = invItems(fromInv), dst = invItems(toInv);
    const a = src[fromSlot];
    if (!a) return;
    if (toSlot < 1 || toSlot > invSlots(toInv)) return;
    amount = clamp(Number(amount) || a.amount, 1, a.amount);
    const b = dst[toSlot];
    const cross = fromInv !== toInv;
    const aw = Number(a.weight) || 0;

    if (b) {
        if (b.name === a.name) {
            if (a.unique || b.unique) return fail(fromInv, fromSlot, "هذا الغرض لا يمكن جمعه في نفس الخانة");
            if (cross && !fits(toInv, aw * amount)) return fail(fromInv, fromSlot, "الوزن لا يكفي");
            b.amount += amount;
            a.amount -= amount;
            if (a.amount <= 0) delete src[fromSlot];
            sendMove(fromInv, toInv, fromSlot, toSlot, a.amount, amount);
        } else {
            if (amount !== a.amount) return fail(fromInv, fromSlot, "لا يمكن تبديل جزء من الكمية مع غرض مختلف");
            const bw = Number(b.weight) || 0;
            if (cross && (!fits(toInv, aw * a.amount, bw * b.amount) || !fits(fromInv, bw * b.amount, aw * a.amount)))
                return fail(fromInv, fromSlot, "الوزن لا يكفي للتبديل");
            src[fromSlot] = { ...b, slot: fromSlot };
            dst[toSlot] = { ...a, slot: toSlot };
            sendMove(fromInv, toInv, fromSlot, toSlot, a.amount, b.amount);
        }
    } else {
        if (cross && !fits(toInv, aw * amount))
            return fail(fromInv, fromSlot, toInv === "player" ? "لا يمكنك حمل المزيد، الحد الأقصى " + kg(S.maxW) + " كغم" : "المخزن ممتلئ");
        const moved = { ...a, amount, slot: toSlot };
        a.amount -= amount;
        if (a.amount <= 0) delete src[fromSlot];
        dst[toSlot] = moved;
        sendMove(fromInv, toInv, fromSlot, toSlot, a.amount, amount);
    }

    if (S.sel && S.sel.inv === fromInv && S.sel.slot === fromSlot && !src[fromSlot]) S.sel = { inv: toInv, slot: toSlot };
    render();
}

function findSlot(toInv, item, allowStack = true) {
    const dst = invItems(toInv);
    const n = invSlots(toInv);
    if (allowStack && !item.unique) {
        for (const k in dst) {
            const it = dst[k];
            if (it && it.name === item.name && !it.unique) return Number(k);
        }
    }
    const order = toInv === "player" ? [...range(S.hot + 1, n), ...range(1, S.hot)] : range(1, n);
    const free = order.find((i) => !dst[i]);
    return free === undefined ? null : free;
}

function quickMove(inv, slot, amount) {
    if (!S.other) return;
    const it = getItem(inv, slot);
    if (!it) return;
    if (isShop()) {
        if (inv === "other") buy(slot, amount);
        return;
    }
    const to = inv === "player" ? "other" : "player";
    const target = findSlot(to, it);
    if (target === null) return fail(inv, slot, to === "player" ? "لا توجد خانة فارغة في حقيبتك" : "لا توجد خانة فارغة في المخزن");
    moveItem(inv, slot, to, target, amount);
}

function splitItem(inv, slot, amount) {
    if (inv === "other" && isShop()) return;
    const it = getItem(inv, slot);
    if (!it || it.amount <= 1) return;
    amount = clamp(amount || Math.floor(it.amount / 2), 1, it.amount - 1);
    const target = findSlot(inv, it, false);
    if (target === null) return fail(inv, slot, "لا توجد خانة فارغة للتقسيم");
    moveItem(inv, slot, inv, target, amount);
}

async function buy(slot, amount) {
    if (!isShop()) return;
    const it = S.other.items[slot];
    if (!it) return;
    amount = clamp(Number(amount) || 1, 1, it.amount);
    if (!fits("player", (Number(it.weight) || 0) * amount)) return fail("other", slot, "لا يمكنك حمل هذه الكمية");
    const ok = await post("AttemptPurchase", { item: it, amount, shop: S.other.name });
    if (ok === true) {
        it.amount -= amount;
        if (it.amount <= 0) delete S.other.items[slot];
        toast(`تم شراء ${it.label} x${amount}`, "success");
        render();
    } else {
        fail("other", slot);
    }
}

function useItem(slot) {
    const it = S.player[slot];
    if (!it) return;
    if (!canUse(it)) return fail("player", slot, "هذا الغرض غير قابل للاستخدام");
    post("UseItem", { inventory: "player", item: it });
    const el = document.querySelector(`#playerPanel .slot[data-slot="${slot}"]`);
    if (el) { el.classList.remove("flash"); void el.offsetWidth; el.classList.add("flash"); }
    if (it.shouldClose) close();
}

/* ---------------- اختيار اللاعب عند الإعطاء ---------------- */
const PK = { open: false, list: [], sel: null, slot: null, amount: 1 };

function closePicker() {
    if (!PK.open) return;
    PK.open = false;
    $("#picker").classList.add("hidden");
    post("HighlightPlayer", { id: null });
}

function selectPlayer(id) {
    PK.sel = id;
    document.querySelectorAll("#pkList .pk-row").forEach((r) => r.classList.toggle("sel", Number(r.dataset.id) === id));
    post("HighlightPlayer", { id });
}

async function giveItem(slot, amount) {
    const it = S.player[slot];
    if (!it) return;
    amount = clamp(Number(amount) || it.amount, 1, it.amount);
    const players = await post("GetNearbyPlayers", {});
    if (!Array.isArray(players) || players.length === 0) return fail("player", slot, "ماكو لاعب قريب منك");
    PK.list = players;
    PK.slot = slot;
    PK.amount = amount;
    $("#pkSub").textContent = `الغرض: ${it.label || it.name} × ${amount}  •  اللاعبين القريبين`;
    const list = $("#pkList");
    list.replaceChildren();
    players.forEach((p) => {
        const row = document.createElement("div");
        row.className = "pk-row";
        row.dataset.id = p.id;
        const id = document.createElement("div"); id.className = "pk-id"; id.textContent = p.id;
        const name = document.createElement("div"); name.className = "pk-name"; name.textContent = p.name;
        const dist = document.createElement("div"); dist.className = "pk-dist"; dist.textContent = `${p.dist.toFixed(1)} م`;
        row.append(id, name, dist);
        row.addEventListener("click", () => selectPlayer(p.id));
        list.appendChild(row);
    });
    PK.open = true;
    $("#picker").classList.remove("hidden");
    selectPlayer(players[0].id); // الأقرب محدد تلقائياً
}

async function confirmGive() {
    const it = S.player[PK.slot];
    const target = PK.sel;
    const slot = PK.slot;
    if (!it || !target) return closePicker();
    closePicker();
    // الحقيبة تتحدث تلقائياً من السيرفر بعد الإعطاء
    const ok = await post("GiveItem", { item: it, amount: PK.amount, slot: it.slot, info: it.info, target });
    if (ok !== true) fail("player", slot);
}

$("#pkGo").addEventListener("click", confirmGive);
$("#pkCancel").addEventListener("click", closePicker);

async function dropToGround(slot, amount) {
    const it = S.player[slot];
    if (!it) return;
    amount = clamp(Number(amount) || it.amount, 1, it.amount);
    if (S.other) {
        if (S.other.kind === "drop") return quickMove("player", slot, amount);
        return fail("player", slot, "أغلق المخزن المفتوح أولاً لرمي الغرض");
    }
    const newItem = { ...it, amount, slot: 1, inventory: "other" };
    const res = await post("DropItem", { ...newItem, fromSlot: it.slot });
    if (typeof res === "string" && res.startsWith("drop-")) {
        if (!S.open) { post("CloseInventory", { name: res }); return; }
        S.other = { name: res, label: res, kind: "drop", maxW: S.dropW, slots: S.dropSlots, items: { 1: { ...newItem } } };
        delete S.other.items[1].inventory;
        render();
    } else {
        fail("player", slot);
    }
}

function copyText(text) {
    const el = document.createElement("textarea");
    el.value = String(text);
    document.body.appendChild(el);
    el.select();
    try { document.execCommand("copy"); toast("تم نسخ الرقم التسلسلي", "success"); } catch (e) {}
    el.remove();
}

/* ---------------- ملحقات السلاح ---------------- */
async function openAttachments(slot) {
    const it = S.player[slot];
    if (!it) return;
    S.attach = { weapon: it, list: [] };
    renderAttach();
    const res = await post("GetWeaponData", { weapon: it.name, ItemData: it });
    if (!S.attach) return;
    if (res && Array.isArray(res.AttachmentData)) S.attach.list = res.AttachmentData;
    renderAttach();
}

async function removeAttachment(i) {
    if (!S.attach) return;
    const at = S.attach.list[i];
    if (!at) return;
    S.attach.list.splice(i, 1);
    renderAttach();
    const res = await post("RemoveAttachment", { AttachmentData: at, WeaponData: S.attach.weapon });
    if (!S.attach) return;
    if (res && res.WeaponData) {
        S.attach.weapon = res.WeaponData;
        if (Array.isArray(res.Attachments)) S.attach.list = res.Attachments;
        toast("تمت إزالة الملحق", "success");
    } else {
        S.attach.list.splice(i, 0, at);
        toast("تعذر إزالة الملحق", "error");
    }
    renderAttach();
}

function renderAttach() {
    const m = $("#attach");
    if (!S.attach) { m.classList.add("hidden"); return; }
    m.classList.remove("hidden");
    $("#attachWeapon").replaceChildren(iconNode(S.attach.weapon, "ico"));
    $("#attachName").textContent = S.attach.weapon.label || S.attach.weapon.name;
    const list = $("#attachList");
    list.replaceChildren();
    if (!S.attach.list.length) {
        const p = document.createElement("p");
        p.className = "empty-msg";
        p.textContent = "لا توجد ملحقات على هذا السلاح";
        list.appendChild(p);
        return;
    }
    S.attach.list.forEach((at, i) => {
        const el = buildSlot(null, i, { image: at.attachment + ".png", label: at.label, amount: 1 });
        el.querySelector(".cnt").remove();
        el.title = "إزالة " + at.label;
        el.onclick = () => removeAttachment(i);
        list.appendChild(el);
    });
}
$("#attachClose").onclick = () => { S.attach = null; renderAttach(); };

/* ---------------- السحب والإفلات ---------------- */
function startDrag(e) {
    const p = S.press;
    const it = getItem(p.inv, p.slot);
    if (!it) { S.press = null; return; }
    const ghost = buildSlot(null, 0, it, { price: p.inv === "other" && isShop() });
    ghost.classList.add("ghost");
    ghost.style.transform = `scale(${(S.scale || 1) * 1.05})`;
    document.body.appendChild(ghost);
    S.drag = { inv: p.inv, slot: p.slot, ghost, over: null };
    moveGhost(e);
    if (p.inv === "player") {
        const side = $("#side");
        side.classList.add("dragging");
        $("#zones").classList.remove("hidden");
        document.querySelector(".zone.use").classList.toggle("hidden", !canUse(it));
        document.querySelector(".zone.ground").classList.toggle("hidden", !!S.other && S.other.kind !== "drop");
    }
    const src = document.querySelector(`#${p.inv === "player" ? "playerPanel" : "otherPanel"} .slot[data-slot="${p.slot}"]`);
    if (src) src.classList.add("src");
}

function moveGhost(e) {
    const g = S.drag.ghost;
    g.style.left = e.clientX - g.offsetWidth / 2 + "px";
    g.style.top = e.clientY - g.offsetHeight / 2 + "px";
    const els = document.elementsFromPoint(e.clientX, e.clientY);
    const over = els.find((x) => (x.classList.contains("slot") && x.dataset.inv) || x.dataset.zone) || null;
    if (over !== S.drag.over) {
        if (S.drag.over) S.drag.over.classList.remove("over");
        if (over) over.classList.add("over");
        S.drag.over = over;
    }
}

function endDrag() {
    if (S.drag) {
        S.drag.ghost.remove();
        if (S.drag.over) S.drag.over.classList.remove("over");
    }
    S.drag = null;
    S.press = null;
    $("#side").classList.remove("dragging");
    $("#zones").classList.add("hidden");
    document.querySelectorAll(".slot.src").forEach((x) => x.classList.remove("src"));
}

function finishDrag(e) {
    const { inv, slot } = S.drag;
    const els = document.elementsFromPoint(e.clientX, e.clientY);
    const target = els.find((x) => x.classList.contains("slot") && x.dataset.inv);
    const zone = els.find((x) => x.dataset && x.dataset.zone);
    const shopSrc = inv === "other" && isShop();
    const amount = amountFor(inv, slot, !shopSrc);
    endDrag();

    if (target) {
        moveItem(inv, slot, target.dataset.inv, Number(target.dataset.slot), amount);
    } else if (zone && inv === "player") {
        const z = zone.dataset.zone;
        if (z === "use") useItem(slot);
        else if (z === "give") giveItem(slot, amount);
        else if (z === "ground") dropToGround(slot, amount);
    } else {
        render();
    }
}

document.addEventListener("mousedown", (e) => {
    if (!S.open || S.attach) return;
    if (e.button !== 0) return;
    const el = e.target.closest(".slot[data-inv]");
    if (!el) return;
    e.preventDefault();
    if (document.activeElement && document.activeElement.tagName === "INPUT") document.activeElement.blur();
    const inv = el.dataset.inv, slot = Number(el.dataset.slot);
    const it = getItem(inv, slot);
    if (!it) { select(inv, slot); return; }
    if (e.shiftKey) { splitItem(inv, slot, Math.floor(it.amount / 2)); return; }
    S.press = { inv, slot, x: e.clientX, y: e.clientY };
});

document.addEventListener("mousemove", (e) => {
    if (S.drag) { moveGhost(e); return; }
    if (S.press && Math.hypot(e.clientX - S.press.x, e.clientY - S.press.y) > 5) startDrag(e);
});

document.addEventListener("mouseup", (e) => {
    if (e.button !== 0) return;
    if (S.drag) { finishDrag(e); return; }
    if (S.press) {
        const { inv, slot } = S.press;
        S.press = null;
        const now = Date.now();
        const last = S.lastClick;
        if (last && last.inv === inv && last.slot === slot && now - last.t < 350) {
            S.lastClick = null;
            doubleAction(inv, slot);
            return;
        }
        S.lastClick = { inv, slot, t: now };
        select(inv, slot);
    }
});

document.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    if (!S.open || S.attach || S.drag) return;
    const el = e.target.closest(".slot[data-inv]");
    if (!el) return;
    const inv = el.dataset.inv, slot = Number(el.dataset.slot);
    if (!getItem(inv, slot)) return;
    if (S.other) {
        quickMove(inv, slot, amountFor(inv, slot, !(inv === "other" && isShop())));
    } else if (inv === "player") {
        useItem(slot);
    }
});

/* ---------------- أزرار الكمية ---------------- */
const selItem = () => S.sel && getItem(S.sel.inv, S.sel.slot);
$("#aMin").onclick = () => { const a = $("#amt"); a.value = Math.max(1, (+a.value || 1) - 1); };
$("#aPlus").onclick = () => { const a = $("#amt"); const it = selItem(); a.value = Math.min(it ? it.amount : 1, (+a.value || 0) + 1); };
$("#aAll").onclick = () => { const it = selItem(); if (it) $("#amt").value = it.amount; };
$("#aHalf").onclick = () => { const it = selItem(); if (it) $("#amt").value = Math.max(1, Math.floor(it.amount / 2)); };
$("#amt").addEventListener("change", () => { const it = selItem(); if (it) $("#amt").value = clamp(parseInt($("#amt").value, 10) || 1, 1, it.amount); });

/* ---------------- فتح وإغلاق ---------------- */
function openInventory(d) {
    S.open = true;
    S.slots = Number(d.slots) || 35;
    S.hot = Number(d.hotbar) || 5;
    S.maxW = Number(d.maxweight) || 150000;
    S.dropSlots = Number(d.dropSlots) || 50;
    S.dropW = Number(d.dropWeight) || 1000000;
    S.openKey = String(d.openKey || "TAB");
    S.player = toMap(d.inventory);
    S.sel = null;
    S.attach = null;
    if (d.other && d.other.name) {
        S.other = {
            name: d.other.name,
            label: d.other.label,
            kind: kindOf(d.other.name),
            maxW: Number(d.other.maxweight) || 0,
            slots: Number(d.other.slots) || 0,
            items: toMap(d.other.inventory),
        };
    } else {
        S.other = null;
    }
    $("#hotbar").classList.add("hidden");
    $("#stage").classList.remove("hidden");
    renderAttach();
    render();
}

function close() {
    if (!S.open) return;
    closePicker();
    const name = S.other ? S.other.name : "";
    endDrag();
    S.open = false;
    S.other = null;
    S.sel = null;
    S.attach = null;
    renderAttach();
    $("#stage").classList.add("hidden");
    post("CloseInventory", { name });
}

function updateInventory(d) {
    if (d.inventory !== undefined) S.player = toMap(d.inventory);
    if (d.otherItems && S.other) S.other.items = toMap(d.otherItems);
    if (!S.open) return;
    render();
    if (d.errorSlot) fail(d.errorInventory && d.errorInventory !== "player" ? "other" : "player", d.errorSlot);
}

/* ---------------- الشريط السريع والإشعارات ---------------- */
function toggleHotbar(d) {
    const bar = $("#hotbar");
    if (!d.open || S.open) { bar.classList.add("hidden"); return; }
    const items = Array.isArray(d.items) ? d.items : Object.values(d.items || {});
    bar.replaceChildren();
    for (let i = 1; i <= 5; i++) bar.appendChild(buildSlot(null, i, items[i - 1] || null, { key: i }));
    bar.classList.remove("hidden");
}

function itemBox(d) {
    const it = d.item || {};
    const kind = d.type === "add" ? "add" : d.type === "use" ? "use" : "remove";
    const title = kind === "add" ? "تم الاستلام" : kind === "use" ? "تم الاستخدام" : "تمت الإزالة";
    const box = document.createElement("div");
    box.className = "ibox " + kind;
    box.appendChild(iconNode(it, "ico"));
    const txt = document.createElement("div");
    const b = document.createElement("b");
    b.textContent = title;
    const s = document.createElement("span");
    s.textContent = it.label || it.name || "";
    const em = document.createElement("em");
    em.textContent = "x" + (d.amount || 1);
    s.appendChild(em);
    txt.append(b, s);
    box.appendChild(txt);
    const wrap = $("#itemBoxes");
    wrap.appendChild(box);
    while (wrap.children.length > 5) wrap.firstChild.remove();
    setTimeout(() => box.classList.add("out"), 2700);
    setTimeout(() => box.remove(), 3000);
}

function requiredItems(d) {
    const box = $("#required");
    if (!d.toggle) { box.classList.add("hidden"); box.replaceChildren(); return; }
    box.replaceChildren();
    (d.items || []).forEach((r) => {
        const el = buildSlot(null, 0, { image: r.image, label: r.label, amount: 1 });
        el.querySelector(".cnt").remove();
        const n = document.createElement("b");
        n.className = "need";
        n.textContent = "مطلوب";
        el.appendChild(n);
        box.appendChild(el);
    });
    box.classList.remove("hidden");
}

/* ---------------- رسائل اللعبة ---------------- */
window.addEventListener("message", ({ data }) => {
    if (!data || !data.action) return;
    switch (data.action) {
        case "open": openInventory(data); break;
        case "close": close(); break;
        case "update": updateInventory(data); break;
        case "toggleHotbar": toggleHotbar(data); break;
        case "itemBox": itemBox(data); break;
        case "requiredItem": requiredItems(data); break;
    }
});

/* ---------------- لوحة المفاتيح ---------------- */
window.addEventListener("keydown", (e) => {
    if (!S.open) return;
    const key = e.key.toLowerCase();
    const openKey = S.openKey.toLowerCase();
    if (key === "escape" || key === openKey || (openKey === "tab" && key === "tab")) {
        e.preventDefault();
        if (PK.open) { closePicker(); return; }
        if (S.attach && key === "escape") { S.attach = null; renderAttach(); return; }
        close();
        return;
    }
    if (key === "tab") { e.preventDefault(); return; }
    if (e.target.tagName === "INPUT") {
        if (key === "enter") e.target.blur();
        return;
    }
    const n = parseInt(e.key, 10);
    if (n >= 1 && n <= S.hot) useItem(n);
});

window.addEventListener("resize", () => { if (S.open) fit(); });
