const $ = s => document.querySelector(s);
const post = (name, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).catch(() => {});

let items = {}, slots = {}, weight = 0, maxW = 150, N = 30, H = 5;
let sel = null, isOpen = false, dragFrom = null;

const CIRC = 263.9;

/* ---------- رسم الخانات ---------- */
function iconNode(d) {
  const box = document.createElement('div');
  box.className = 'ico';
  const emoji = () => { box.textContent = d.icon || '📦'; };
  if (d.image) {
    const img = new Image();
    img.src = 'img/' + d.image;
    img.onerror = () => { img.remove(); emoji(); };
    box.appendChild(img);
  } else emoji();
  return box;
}

function buildSlot(i) {
  const el = document.createElement('div');
  el.className = 'slot';
  el.dataset.slot = i;
  const it = slots[i];

  if (i > N) {
    const k = document.createElement('b');
    k.className = 'key';
    k.textContent = i - N;
    el.appendChild(k);
  }
  if (it) {
    const d = items[it.name] || { label: it.name, icon: '❔' };
    el.classList.add('full');
    el.draggable = true;
    el.appendChild(iconNode(d));
    const nm = document.createElement('span');
    nm.className = 'nm';
    nm.textContent = d.label;
    el.appendChild(nm);
    if (it.count > 1 || d.stack !== false) {
      const c = document.createElement('b');
      c.className = 'cnt';
      c.textContent = it.count;
      el.appendChild(c);
    }
  }
  if (sel === i) el.classList.add('selected');

  el.addEventListener('click', () => select(i));
  el.addEventListener('dblclick', () => it && post('use', { slot: i }));
  el.addEventListener('contextmenu', e => { e.preventDefault(); if (it) post('use', { slot: i }); });

  el.addEventListener('dragstart', e => {
    dragFrom = i;
    el.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', String(i));
  });
  el.addEventListener('dragend', () => { el.classList.remove('dragging'); dragFrom = null; });
  el.addEventListener('dragover', e => { e.preventDefault(); el.classList.add('over'); });
  el.addEventListener('dragleave', () => el.classList.remove('over'));
  el.addEventListener('drop', e => {
    e.preventDefault();
    el.classList.remove('over');
    if (dragFrom && dragFrom !== i) {
      const data = { from: dragFrom, to: i };
      if (sel === dragFrom) data.amount = getAmount();
      post('move', data);
    }
    dragFrom = null;
  });
  return el;
}

function render() {
  const grid = $('#grid'), bar = $('#hotbar');
  grid.replaceChildren(); bar.replaceChildren();
  for (let i = 1; i <= N; i++) grid.appendChild(buildSlot(i));
  for (let i = N + 1; i <= N + H; i++) bar.appendChild(buildSlot(i));
  renderWeight();
  renderDetail();
}

function renderWeight() {
  $('#w').textContent = +weight.toFixed(2);
  $('#mw').textContent = maxW;
  const ratio = Math.min(weight / maxW, 1);
  const ring = $('#ring');
  ring.style.strokeDashoffset = CIRC * (1 - ratio);
  ring.classList.toggle('warn', ratio >= 0.75 && ratio < 1);
  ring.classList.toggle('full', ratio >= 0.999);
}

/* ---------- التفاصيل ---------- */
function getAmount() {
  const it = slots[sel];
  if (!it) return 1;
  const v = parseInt($('#amt').value, 10) || 1;
  return Math.max(1, Math.min(it.count, v));
}

function select(i) {
  sel = slots[i] ? i : null;
  if (sel) $('#amt').value = slots[sel].count;
  render();
}

function renderDetail() {
  const box = $('#detail');
  if (sel && !slots[sel]) sel = null;
  box.classList.toggle('empty', !sel);
  if (!sel) return;
  const it = slots[sel];
  const d = items[it.name] || { label: it.name, icon: '❔', weight: 0, desc: '' };

  const di = $('#dIcon');
  di.replaceChildren(iconNode(d));
  $('#dName').textContent = d.label;
  $('#dDesc').textContent = d.desc || '';
  $('#dWeight').textContent = (d.weight || 0) + ' كغم';
  $('#dCount').textContent = it.count;
  $('#dTotal').textContent = +((d.weight || 0) * it.count).toFixed(2) + ' كغم';
  $('#bUse').style.display = d.usable ? '' : 'none';
  const a = $('#amt');
  a.max = it.count;
  if (+a.value > it.count) a.value = it.count;
}

$('#aMin').onclick  = () => { const a = $('#amt'); a.value = Math.max(1, (+a.value || 1) - 1); };
$('#aPlus').onclick = () => { const a = $('#amt'); a.value = Math.min(slots[sel]?.count || 1, (+a.value || 0) + 1); };
$('#aAll').onclick  = () => { if (slots[sel]) $('#amt').value = slots[sel].count; };
$('#aHalf').onclick = () => { if (slots[sel]) $('#amt').value = Math.max(1, Math.floor(slots[sel].count / 2)); };
$('#bUse').onclick  = () => sel && post('use', { slot: sel });
$('#bDrop').onclick = () => sel && post('drop', { slot: sel, amount: getAmount() });
$('#bGive').onclick = () => sel && post('give', { slot: sel, amount: getAmount() });

/* ---------- تنبيهات ---------- */
function toast(text, kind = 'info') {
  const t = document.createElement('div');
  t.className = 'toast ' + kind;
  t.textContent = text;
  $('#toasts').appendChild(t);
  setTimeout(() => t.classList.add('out'), 2600);
  setTimeout(() => t.remove(), 3000);
}

/* ---------- رسائل من اللعبة ---------- */
window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'init':
      items = data.items || {}; N = data.slots; H = data.hotbar; maxW = data.maxWeight;
      render();
      break;
    case 'sync':
      slots = {};
      (data.slots || []).forEach(s => { slots[s.slot] = { name: s.name, count: s.count }; });
      weight = data.weight || 0;
      render();
      break;
    case 'open':
      isOpen = true;
      document.body.classList.add('open');
      $('#app').classList.remove('hidden');
      $('#prompt').classList.add('hidden');
      break;
    case 'close':
      isOpen = false;
      document.body.classList.remove('open');
      $('#app').classList.add('hidden');
      break;
    case 'toast':
      toast(data.text, data.kind);
      break;
    case 'flash': {
      const el = document.querySelector(`#hotbar .slot[data-slot="${data.slot}"]`);
      if (el) { el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash'); }
      break;
    }
    case 'prompt':
      $('#promptText').textContent = data.text || '';
      $('#prompt').classList.toggle('hidden', !data.show);
      break;
  }
});

/* ---------- لوحة المفاتيح ---------- */
window.addEventListener('keydown', e => {
  if (!isOpen) return;
  if (e.key === 'Escape' || e.key === 'F2') { e.preventDefault(); post('close'); return; }
  if (e.target.tagName === 'INPUT') return;
  const n = parseInt(e.key, 10);
  if (n >= 1 && n <= H) post('use', { slot: N + n });
});

post('ready');
