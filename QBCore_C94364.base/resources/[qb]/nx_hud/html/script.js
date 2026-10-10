(() => {
'use strict';

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nx_hud';
const post = (name, data = {}) =>
  fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});

/* ---------------- Settings ---------------- */
const DEFAULTS = {
  theme: 'cyber', speedStyle: 'arc', units: 'kmh', scale: 1, opacity: 1, hideFull: true, cinematic: false, frame: true,
  show: { status: true, vehicle: true, job: true },
  pos: { status: { x: 1.5, y: 88 }, vehicle: { x: 76, y: 66 }, job: { x: 1.5, y: 2 } },
};
const clone = o => JSON.parse(JSON.stringify(o));
const merge = (base, over) => {
  for (const k in over) {
    if (over[k] && typeof over[k] === 'object' && !Array.isArray(over[k]) && base[k] && typeof base[k] === 'object') merge(base[k], over[k]);
    else if (k in base) base[k] = over[k];
  }
  return base;
};
const getPath = (o, p) => p.split('.').reduce((a, k) => a[k], o);
const setPath = (o, p, v) => { const ks = p.split('.'); const l = ks.pop(); ks.reduce((a, k) => a[k], o)[l] = v; };

let S = clone(DEFAULTS);
let maxSpeed = 280;
let menuOpen = false, inVehicle = false, jobShown = false, hudVisible = true;
const app = $('#app');

let saveTimer;
const save = () => { clearTimeout(saveTimer); saveTimer = setTimeout(() => post('save', { json: JSON.stringify(S) }), 400); };

/* ---------------- Status bars ---------------- */
// [low threshold, critical threshold]; armor and stamina never pulse
const LOW = { health: [30, 15], hunger: [20, 10], thirst: [20, 10] };
const vals = { health: 100, armor: 0, hunger: 100, thirst: 100, stamina: 100 };
const bar = {};
for (const k in vals) {
  const root = $('#b-' + k);
  bar[k] = { root, fill: $('.fill', root), num: $('.num', root) };
}

function renderBar(k) {
  const v = vals[k], b = bar[k];
  b.fill.style.transform = `scaleX(${v / 100})`;
  if (b.num) b.num.textContent = v;
  const low = LOW[k];
  b.root.classList.toggle('crit', !!low && v <= low[1]);
  b.root.classList.toggle('low', !!low && v > low[1] && v <= low[0]);
  // Armor at 0 reads as "nothing"; the others fade when full
  const idle = k === 'armor' ? v <= 0 : v >= 100;
  b.root.classList.toggle('fade', S.hideFull && idle && k !== 'health');
}
const renderRings = () => { for (const k in bar) renderBar(k); };
/* ---------------- Vehicle ---------------- */
const el = id => document.getElementById(id);
const spdArc = el('spdArc'), rpmArc = el('rpmArc'), needle = el('needle'), spdTxt = el('spd'),
  gearTxt = el('gear'), unitTxt = el('unit'), fuelBar = el('fuelBar'), fuelTxt = el('fuelTxt'),
  rpmBar = el('rpmBar'), beltIco = el('beltIco'), engIco = el('engIco'), bodyIco = el('bodyIco');
let lastVeh = { speed: 0, rpm: 0, gear: 'N', fuel: 100, engine: 100, body: 100, belt: false, warn: false, canBelt: true };

function buildTicks() {
  const g = el('ticks'); g.innerHTML = '';
  const unit = S.units === 'mph' ? 0.621371 : 1;
  const top = Math.round(maxSpeed * unit / 20) * 20, step = top / 7;
  for (let i = 0; i <= 7; i++) {
    const a = (-135 + (270 * i) / 7) * Math.PI / 180;
    const sx = Math.sin(a), cy = -Math.cos(a);
    g.insertAdjacentHTML('beforeend',
      `<line x1="${100 + sx * 84}" y1="${100 + cy * 84}" x2="${100 + sx * 76}" y2="${100 + cy * 76}"/>` +
      `<text x="${100 + sx * 62}" y="${100 + cy * 62}">${Math.round(step * i)}</text>`);
  }
}

const condClass = pct => (pct > 60 ? '' : pct > 30 ? 'yel' : 'red'); // White -> Yellow -> Red
function setCls(node, cls) { node.setAttribute('class', cls); }

function renderVehicle() {
  const v = lastVeh, f = S.units === 'mph' ? 0.621371 : 1;
  const spd = Math.round(v.speed * f);
  const frac = Math.min(1, v.speed / maxSpeed);
  spdTxt.textContent = spd;
  unitTxt.textContent = S.units.toUpperCase();
  gearTxt.textContent = v.gear;
  spdArc.setAttribute('stroke-dasharray', `${(75 * frac).toFixed(1)} 100`);
  rpmArc.setAttribute('stroke-dasharray', `${(75 * v.rpm / 100).toFixed(1)} 100`);
  rpmArc.classList.toggle('red', v.rpm > 88);
  needle.style.transform = `rotate(${-135 + 270 * frac}deg)`;
  rpmBar.style.transform = `scaleX(${v.rpm / 100})`;
  fuelBar.style.transform = S.speedStyle === 'digital' ? `scaleX(${v.fuel / 100})` : `scaleY(${v.fuel / 100})`;
  fuelBar.classList.toggle('low', v.fuel < 15);
  fuelTxt.textContent = v.fuel;
  setCls(engIco, condClass(v.engine));
  setCls(bodyIco, condClass(v.body));
  setCls(beltIco, !v.canBelt ? 'na' : v.belt ? 'ok' : v.warn ? 'red blink' : '');
}

/* Seatbelt warning beep (WebAudio: no audio file needed) */
let actx, beepTimer;
function beep() {
  try {
    actx = actx || new AudioContext();
    const o = actx.createOscillator(), g = actx.createGain();
    o.type = 'sine'; o.frequency.value = 900; g.gain.value = 0.07;
    o.connect(g); g.connect(actx.destination);
    o.start(); o.stop(actx.currentTime + 0.14);
  } catch (e) { /* audio blocked: icon still blinks */ }
}
function setWarn(on) {
  if (on && !beepTimer) { beep(); beepTimer = setInterval(beep, 1200); }
  else if (!on && beepTimer) { clearInterval(beepTimer); beepTimer = null; }
}

/* ---------------- Layout / visibility ---------------- */
function applyLayout() {
  app.dataset.theme = S.theme;
  app.classList.toggle('noframe', !S.frame);
  app.style.setProperty('--s', S.scale);
  app.style.setProperty('--o', S.opacity);
  $('#w-vehicle').dataset.style = S.speedStyle;
  document.body.classList.toggle('cine', S.cinematic);
  for (const id of ['status', 'vehicle', 'job']) {
    const w = $('#w-' + id), p = S.pos[id];
    w.style.left = p.x + '%';
    w.style.top = p.y + '%';
  }
  applyVisibility();
  buildTicks();
  renderRings();
  renderVehicle();
}

function applyVisibility() {
  const set = (id, shouldShow) => {
    const w = $('#w-' + id);
    w.classList.toggle('off', !S.show[id]);
    // While the menu is open every enabled widget is previewed so it can be dragged
    w.classList.toggle('hidden', !(hudVisible && shouldShow) && !menuOpen);
  };
  set('status', true);
  set('vehicle', inVehicle);
  set('job', jobShown);
}

/* ---------------- Menu wiring ---------------- */
function syncMenu() {
  $$('#menu [data-key]').forEach(n => {
    const v = getPath(S, n.dataset.key);
    if (n.classList.contains('seg')) $$('button', n).forEach(b => b.classList.toggle('on', b.dataset.val === v));
    else if (n.type === 'checkbox') n.checked = !!v;
    else if (n.type === 'range') n.value = v;
  });
  $('[data-out=scale]').textContent = Math.round(S.scale * 100) + '%';
  $('[data-out=opacity]').textContent = Math.round(S.opacity * 100) + '%';
}

function change(key, val) {
  setPath(S, key, val);
  if (key === 'cinematic') post('cinematic', { on: val });
  applyLayout(); syncMenu(); save();
}

$('#menu').addEventListener('click', e => {
  const b = e.target.closest('.seg button');
  if (b) change(b.parentElement.dataset.key, b.dataset.val);
});
$('#menu').addEventListener('input', e => {
  const n = e.target;
  if (n.type === 'checkbox') change(n.dataset.key, n.checked);
  else if (n.type === 'range') change(n.dataset.key, parseFloat(n.value));
});
$('#mReset').onclick = () => { const c = S.cinematic; S = clone(DEFAULTS); S.cinematic = c; applyLayout(); syncMenu(); save(); };

function toggleMenu(open) {
  menuOpen = open;
  document.body.classList.toggle('menu', open);
  document.body.classList.toggle('editing', open);
  syncMenu(); applyVisibility();
}
function closeMenu() { toggleMenu(false); post('close'); }
$('#mClose').onclick = $('#mDone').onclick = closeMenu;
addEventListener('keydown', e => {
  if (menuOpen && (e.key === 'Escape' || e.key.toLowerCase() === 'u')) closeMenu();
});

/* ---------------- Drag to move (only while editing) ---------------- */
let drag = null;
addEventListener('pointerdown', e => {
  const w = e.target.closest('.widget');
  if (!menuOpen || !w) return;
  const r = w.getBoundingClientRect();
  drag = { w, dx: e.clientX - r.left, dy: e.clientY - r.top };
  w.setPointerCapture?.(e.pointerId);
});
addEventListener('pointermove', e => {
  if (!drag) return;
  const x = Math.max(0, Math.min(98, (e.clientX - drag.dx) / innerWidth * 100));
  const y = Math.max(0, Math.min(98, (e.clientY - drag.dy) / innerHeight * 100));
  drag.w.style.left = x + '%'; drag.w.style.top = y + '%';
  S.pos[drag.w.dataset.id] = { x: +x.toFixed(2), y: +y.toFixed(2) };
});
addEventListener('pointerup', () => { if (drag) { drag = null; save(); } });

/* ---------------- Messages from Lua ---------------- */
const H = {
  init(d) {
    maxSpeed = d.maxSpeed || maxSpeed;
    if (d.settings) { try { S = merge(clone(DEFAULTS), JSON.parse(d.settings)); } catch (e) { /* corrupt save: use defaults */ } }
    if (S.cinematic) post('cinematic', { on: true });
    applyLayout(); syncMenu();
  },
  status(d) {
    for (const k in vals) if (d[k] !== undefined) vals[k] = d[k];
    hudVisible = d.visible !== false;
    renderRings(); applyVisibility();
  },
  vehicle(d) {
    inVehicle = !!d.show;
    if (inVehicle) { lastVeh = d; renderVehicle(); setWarn(d.warn); }
    else setWarn(false);
    applyVisibility();
  },
  job(d) {
    jobShown = !!(d.data && d.data.show);
    if (jobShown) { $('#jobIco').textContent = d.data.icon; $('#jobTxt').textContent = `وحدات ${d.data.label}: ${d.data.count}`; }
    applyVisibility();
  },
  menu(d) { toggleMenu(d.open); },
  toggleCinematic() { change('cinematic', !S.cinematic); },
};
addEventListener('message', e => { const h = H[e.data && e.data.action]; if (h) h(e.data); });

applyLayout();
post('ready');
})();


