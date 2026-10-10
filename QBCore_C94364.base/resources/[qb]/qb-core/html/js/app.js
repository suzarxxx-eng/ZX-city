// إشعارات QBCore - تصميم عربي أزرق حديث
const ICONS = {
    success: '<path d="M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z"/>',
    primary: '<path d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2zm6-6V11c0-3.1-1.6-5.6-4.5-6.3V4a1.5 1.5 0 0 0-3 0v.7C7.6 5.4 6 7.9 6 11v5l-2 2v1h16v-1z"/>',
    warning: '<path d="M1 21h22L12 2zm12-3h-2v-2h2zm0-4h-2v-4h2z"/>',
    error: '<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-2h2zm0-4h-2V7h2z"/>',
    police: '<path d="M12 1 3 5v6c0 5.6 3.8 10.7 9 12 5.2-1.3 9-6.4 9-12V5zm0 6.5 1.2 2.6 2.8.3-2.1 1.9.6 2.8L12 13.7l-2.5 1.4.6-2.8L8 10.4l2.8-.3z"/>',
    ambulance: '<path d="M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm-2 11h-3v3h-4v-3H7v-4h3V7h4v3h3z"/>',
};
const TITLES = {
    success: "تم بنجاح",
    primary: "تنبيه",
    warning: "تحذير",
    error: "خطأ",
    police: "الامن العام",
    ambulance: "الإسعاف",
};
const ALIASES = { info: "primary", inform: "primary", danger: "error", bad: "error", good: "success" };

let box = null;
function container() {
    if (box) return box;
    box = document.createElement("div");
    box.id = "notify-container";
    document.body.appendChild(box);
    return box;
}

// نص آمن: يسمح فقط بـ <br> للسطر الجديد
function safeText(el, text) {
    const parts = String(text ?? "").split(/<br\s*\/?>/i);
    parts.forEach((p, i) => {
        if (i) el.appendChild(document.createElement("br"));
        el.appendChild(document.createTextNode(p.replace(/<[^>]*>/g, "")));
    });
}

function notify({ text, type, length, caption }) {
    let kind = String(type || "primary").toLowerCase();
    kind = ALIASES[kind] || kind;
    if (!ICONS[kind]) kind = "primary";
    const duration = Number(length) > 0 ? Number(length) : 5000;

    const item = document.createElement("div");
    item.className = "notify " + kind;
    item.innerHTML = `<div class="n-icon"><svg viewBox="0 0 24 24">${ICONS[kind]}</svg></div><div class="n-body"><b class="n-title"></b><div class="n-msg" dir="auto"></div></div><i class="n-bar"></i>`;
    item.querySelector(".n-title").textContent = TITLES[kind];
    safeText(item.querySelector(".n-msg"), text);
    if (caption) {
        const c = document.createElement("div");
        c.className = "n-cap";
        c.dir = "auto";
        safeText(c, caption);
        item.querySelector(".n-body").appendChild(c);
    }
    item.querySelector(".n-bar").style.animationDuration = duration + "ms";

    const c = container();
    c.appendChild(item);
    while (c.children.length > 5) c.firstChild.remove();
    requestAnimationFrame(() => item.classList.add("in"));

    setTimeout(() => {
        item.classList.remove("in");
        item.classList.add("out");
        setTimeout(() => item.remove(), 350);
    }, duration);
}

window.addEventListener("message", ({ data }) => {
    if (data && data.action === "notify") notify(data);
});
