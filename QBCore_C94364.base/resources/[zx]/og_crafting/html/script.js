const RES = 'og_crafting';
const IMG = 'nui://qb-inventory/html/images/';
const $ = (id) => document.getElementById(id);

const ICONS = {
  all: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  tools: '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z"/>',
  chip: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/>',
  car: '<path d="M5 16V11l2-5h10l2 5v5"/><path d="M3 16h18v3H3z"/><circle cx="7.5" cy="16" r="1.5"/><circle cx="16.5" cy="16" r="1.5"/><path d="M5 11h14"/>',
  med: '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8M8 12h8"/>',
  knife: '<path d="M20 4L9 15l-3 0 0-3L17 1z" transform="translate(0 2)"/><path d="M6 17l-3 3"/>',
  ammo: '<path d="M7 9a2 2 0 0 1 4 0v11H7z"/><path d="M14 9a2 2 0 0 1 4 0v11h-4z"/><path d="M7 16h4M14 16h4"/>',
  scope: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M12 2v5M12 17v5M2 12h5M17 12h5"/>',
  gun: '<path d="M3 8h17l1 3h-6l-1 2h-3l-1 5H6l1-5H3z"/><path d="M11 13v-2"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/><circle cx="12" cy="16" r="1.5"/>',
  cuffs: '<circle cx="7" cy="14" r="4"/><circle cx="17" cy="14" r="4"/><path d="M11 14h2"/><path d="M7 10V7M17 10V7"/>',
  smg: '<path d="M3 9h15v3h-5l-1 2h-2v5H7v-5H3z"/><path d="M18 10h3"/><path d="M12 14v3h2"/>',
  shotgun: '<path d="M2 10h14l2 2h4v2h-6l-2 1H9l-2 4H4l1-4H2z"/>',
  rifle: '<path d="M2 10h12l1-2h3v2h4v2h-6l-2 1h-2l-2 5H7l1-5H2z"/><path d="M10 13v-1"/>',
  attach: '<rect x="4" y="9" width="13" height="6" rx="1"/><path d="M17 11h4v2h-4M8 9V6h5v3"/>',
};
const LOCK = '<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>';
const HAMMER = '<svg viewBox="0 0 24 24"><path d="M15 12l-8.5 8.5a2.1 2.1 0 0 1-3-3L12 9"/><path d="M17.6 15L22 10.6 13.4 2 9 6.4z"/></svg>';

let D = null;
let cat = 'all';
let sel = null;
let qty = 1;
let timer = null;

const post = (n, d = {}) => fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) }).catch(() => {});
const img = (f) => IMG + (f || '');
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fmtTime = (ms) => {
  const s = Math.round(ms / 1000);
  return s >= 60 ? `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` : `${s}s`;
};

const canMake = (r, q = 1) => r.level <= D.level && r.mats.every((m) => m.have >= m.need * q);
const maxMake = (r) => {
  let n = D.maxQty;
  r.mats.forEach((m) => { n = Math.min(n, Math.floor(m.have / m.need)); });
  return Math.max(0, n);
};

function renderHeader() {
  $('tableName').textContent = D.table;
  $('lvNum').textContent = D.level;
  $('lvName').textContent = D.levels[D.level].name;
  const cur = D.levels[D.level].xp;
  const next = D.levels[D.level + 1];
  if (next) {
    $('lvXp').textContent = `${D.xp} / ${next.xp} XP`;
    $('lvBar').style.width = Math.min(100, ((D.xp - cur) / (next.xp - cur)) * 100) + '%';
  } else {
    $('lvXp').textContent = `${D.xp} XP — أعلى مستوى`;
    $('lvBar').style.width = '100%';
  }
  $('speed').textContent = '+' + D.speed + '%';
  $('pips').innerHTML = D.levels.map((l, i) =>
    `<div class="pip ${i < D.level ? 'on' : ''} ${i === D.level ? 'cur' : ''}" title="${esc(l.name)}">${i}</div>`).join('');
}

function renderCats() {
  const list = [{ id: 'all', label: 'الكل', icon: 'all' }].concat(D.categories);
  $('cats').innerHTML = list.map((c) => {
    const n = c.id === 'all' ? D.recipes.length : D.recipes.filter((r) => r.cat === c.id).length;
    if (!n) return '';
    return `<div class="cat ${cat === c.id ? 'on' : ''}" data-c="${c.id}">
      <div class="ci"><svg viewBox="0 0 24 24">${ICONS[c.icon] || ICONS.all}</svg></div>${esc(c.label)}<span class="n">${n}</span></div>`;
  }).join('');
  document.querySelectorAll('.cat').forEach((el) => el.onclick = () => { cat = el.dataset.c; renderCats(); renderGrid(); });
}

function renderGrid() {
  const q = $('search').value.trim().toLowerCase();
  const only = $('onlyCan').checked;
  const list = D.recipes
    .filter((r) => cat === 'all' || r.cat === cat)
    .filter((r) => !q || r.label.toLowerCase().includes(q) || r.item.includes(q))
    .filter((r) => !only || canMake(r))
    .sort((a, b) => a.level - b.level);

  if (!list.length) { $('grid').innerHTML = '<div class="none">ماكو شي هنا</div>'; return; }

  $('grid').innerHTML = list.map((r) => {
    const locked = r.level > D.level;
    return `<div class="rc ${locked ? 'lock' : ''} ${sel === r.idx ? 'sel' : ''}" data-i="${r.idx}">
      <span class="lv">LV ${r.level}</span>
      ${locked ? '' : `<span class="dot ${canMake(r) ? 'ok' : ''}"></span>`}
      ${r.amount > 1 ? `<span class="qtyb">x${r.amount}</span>` : ''}
      ${r.mats.some((m) => m.bp) ? '<span class="bpb">📜</span>' : ''}
      <div class="img"><img src="${img(r.image)}" onerror="this.style.opacity=0"></div>
      <div class="nm">${esc(r.label)}</div>
      ${locked ? `<div class="lockov">${LOCK}يحتاج مستوى ${r.level}</div>` : ''}
    </div>`;
  }).join('');
  document.querySelectorAll('.rc:not(.lock)').forEach((el) => el.onclick = () => {
    sel = Number(el.dataset.i); qty = 1; renderGrid(); renderDetail();
  });
}

function renderDetail() {
  const r = D.recipes.find((x) => x.idx === sel);
  if (!r || r.level > D.level) { $('detail').innerHTML = '<div class="empty">اختار غرض حتى تشوف طريقة تصنيعه</div>'; return; }
  const mx = maxMake(r);
  if (qty > Math.max(1, mx)) qty = Math.max(1, mx);
  const ok = canMake(r, qty);

  $('detail').innerHTML = `
    <div class="dTop">
      <div class="dImg"><img src="${img(r.image)}" onerror="this.style.opacity=0"></div>
      <div class="dName">${esc(r.label)}</div>
      <div class="dDesc">${esc(r.desc)}</div>
    </div>
    <div class="stats">
      <div class="st"><b>${fmtTime(r.time * qty)}</b><span>الوقت</span></div>
      <div class="st"><b style="color:var(--acc)">+${r.xp * qty}</b><span>خبرة</span></div>
      <div class="st"><b>x${r.amount * qty}</b><span>تحصل</span></div>
    </div>
    <div class="mh"><span>المواد المطلوبة</span><span>تكدر تسوي ${mx}</span></div>
    <div class="mats">${r.mats.map((m) => {
      const need = m.need * qty;
      const good = m.have >= need;
      return `<div class="mat ${good ? 'ok' : ''} ${m.bp ? 'bp' : ''}">
        <img src="${img(m.image)}" onerror="this.style.opacity=0">
        <div class="mi"><div class="ml">${m.bp ? '<span class="bpt">مخطوطة</span>' : ''}${esc(m.label)}</div><div class="mb"><i style="width:${Math.min(100, (m.have / need) * 100)}%"></i></div></div>
        <div class="mc">${m.have} <small>/ ${need}</small></div>
      </div>`;
    }).join('')}</div>
    <div class="act">
      <div class="qty"><button id="qP">+</button><span>${qty}</span><button id="qM">−</button></div>
      <button class="go" id="goBtn" ${ok ? '' : 'disabled'}>${HAMMER}${ok ? 'صنّع' : 'المواد ما تكفي'}</button>
    </div>`;

  $('qP').onclick = () => { if (qty < Math.min(D.maxQty, Math.max(1, mx))) { qty++; renderDetail(); } };
  $('qM').onclick = () => { if (qty > 1) { qty--; renderDetail(); } };
  $('goBtn').onclick = () => { if (canMake(r, qty)) post('craft', { idx: r.idx, qty }); };
}

function startProgress(ms) {
  const r = D.recipes.find((x) => x.idx === sel);
  $('pImg').src = r ? img(r.image) : '';
  $('pName').textContent = r ? `${r.label} x${r.amount * qty}` : '';
  $('pSub').textContent = 'جاري التصنيع...';
  $('progress').classList.remove('hidden');
  const bar = $('pBar');
  const start = Date.now();
  clearInterval(timer);
  timer = setInterval(() => {
    const p = Math.min(1, (Date.now() - start) / ms);
    bar.style.width = (p * 100) + '%';
    $('pSub').textContent = `جاري التصنيع... ${fmtTime(Math.max(0, ms - (Date.now() - start)))}`;
    if (p >= 1) clearInterval(timer);
  }, 50);
}

function stopProgress() {
  clearInterval(timer);
  $('progress').classList.add('hidden');
  $('pBar').style.width = '0';
}

let toastT = null;
function toast(msg, big) {
  const t = $('toast');
  t.textContent = msg;
  t.className = 'toast' + (big ? ' big' : '');
  clearTimeout(toastT);
  toastT = setTimeout(() => t.classList.add('hidden'), big ? 4000 : 2500);
}

window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'open') {
    const first = !D || $('app').classList.contains('hidden');
    D = m.data;
    if (first) { cat = 'all'; sel = null; qty = 1; $('search').value = ''; stopProgress(); }
    $('app').classList.remove('hidden');
    renderHeader(); renderCats(); renderGrid(); renderDetail();
  } else if (m.action === 'progress') {
    startProgress(m.ms);
  } else if (m.action === 'stop') {
    stopProgress();
  } else if (m.action === 'done') {
    stopProgress();
    const r = m.result;
    if (r.levelUp !== undefined && r.levelUp !== null) toast(`مستوى جديد! صرت مستوى ${r.levelUp} — ${r.levelName}`, true);
    else toast(`صنعت ${r.label} x${r.amount}  (+${r.xp} XP)`);
  } else if (m.action === 'close') {
    $('app').classList.add('hidden');
    stopProgress();
  }
});

$('closeBtn').onclick = () => post('close');
$('pCancel').onclick = () => { stopProgress(); post('cancel'); };
$('search').oninput = renderGrid;
$('onlyCan').onchange = renderGrid;
window.addEventListener('keyup', (e) => {
  if (e.key === 'Escape' && !$('app').classList.contains('hidden')) post('close');
});
