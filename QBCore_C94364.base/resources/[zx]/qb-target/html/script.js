const RES = typeof GetParentResourceName === "function" ? GetParentResourceName() : "qb-target";
const $ = (s) => document.querySelector(s);
const root = $("#target");
const list = $("#options");

let items = [];
let active = -1;
let open = false;
let focused = false;

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
    }).catch(() => {});
}

// يقبل "fas fa-x" أو "fa-solid fa-x" أو "x"
function iconClass(icon) {
    if (!icon) return "fas fa-circle-dot";
    icon = String(icon).trim();
    if (!icon.includes("fa-")) return "fas fa-" + icon;
    if (!/\bfa[srlbd]?\b|\bfa-(solid|regular|brands|light)\b/.test(icon)) return "fas " + icon;
    return icon;
}

function render() {
    list.replaceChildren();
    items.forEach((it, i) => {
        const li = document.createElement("li");
        li.className = "opt" + (i === active ? " active" : "");
        li.style.animationDelay = i * 25 + "ms";
        const ic = document.createElement("span");
        ic.className = "ic";
        const fa = document.createElement("i");
        fa.className = iconClass(it.icon);
        ic.appendChild(fa);
        const lb = document.createElement("span");
        lb.className = "lb";
        lb.textContent = it.label;
        li.append(ic, lb);
        if (i < 9) {
            const n = document.createElement("span");
            n.className = "num";
            n.textContent = i + 1;
            li.appendChild(n);
        }
        li.addEventListener("mouseenter", () => setActive(i));
        li.addEventListener("click", (e) => { e.stopPropagation(); choose(i); });
        list.appendChild(li);
    });
    root.classList.toggle("has", items.length > 0);
}

function setActive(i) {
    active = i;
    [...list.children].forEach((el, k) => el.classList.toggle("active", k === i));
}

function choose(i) {
    if (!focused || !items[i]) return;
    post("select", { index: i + 1 });
    hide();
}

function close() {
    if (!open) return;
    post("close");
    hide();
}

function hide() {
    open = false;
    focused = false;
    items = [];
    active = -1;
    root.classList.add("hidden");
    root.classList.remove("has", "focus");
    list.replaceChildren();
}

window.addEventListener("message", ({ data }) => {
    if (!data || !data.action) return;
    switch (data.action) {
        case "open":
            open = true;
            focused = false;
            items = [];
            root.classList.remove("hidden", "focus", "has");
            list.replaceChildren();
            break;
        case "options":
            items = Array.isArray(data.options) ? data.options : [];
            active = -1;
            render();
            break;
        case "focus":
            focused = true;
            active = 0;
            root.classList.add("focus");
            setActive(0);
            break;
        case "close":
            hide();
            break;
    }
});

// أثناء الاختيار بالماوس: تشيل إيدك عن Alt أو Escape أو كليك يمين = إغلاق
window.addEventListener("keyup", (e) => {
    if (focused && e.key === "Alt") close();
});

window.addEventListener("keydown", (e) => {
    if (!focused) return;
    if (e.key === "Escape" || e.key === "Backspace") { close(); return; }
    if (!items.length) return;
    if (e.key === "ArrowDown") { setActive((active + 1) % items.length); e.preventDefault(); }
    else if (e.key === "ArrowUp") { setActive((active - 1 + items.length) % items.length); e.preventDefault(); }
    else if (e.key === "Enter") choose(Math.max(0, active));
    else if (/^[1-9]$/.test(e.key)) choose(parseInt(e.key, 10) - 1);
});

window.addEventListener("mousedown", (e) => {
    if (!focused) return;
    if (e.button === 2 || !e.target.closest(".opt")) close();
});
window.addEventListener("contextmenu", (e) => e.preventDefault());
