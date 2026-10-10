// مركز التوظيف: الوظائف + وظيفتي + المتصدرين. التقديم والاستقالة يصيرون من هنا فقط.
// كل نص جاي من السيرفر (أسماء لاعبين...) يدخل بـ textContent حتى ما ينحقن HTML.
(function () {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'og_jobs';
    const $ = (s) => document.querySelector(s);

    function post(name, data = {}) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then((r) => r.text()).then((t) => { try { return JSON.parse(t); } catch (e) { return t; } }).catch(() => null);
    }

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }

    const fmt = (n) => Number(n || 0).toLocaleString('en-US');
    const TITLES = { jobs: 'الوظائف المتاحة', mine: 'وظيفتي', board: 'المتصدرين' };
    const S = { open: false, tab: 'jobs', sel: null, data: null, busy: false };

    const jobInfo = (id) => S.data.list.find((j) => j.id === id);

    function levelInfo(id) {
        const d = S.data;
        const st = d.jobs[id] || { xp: 0, level: 1, earned: 0 };
        const next = d.levels[st.level]; // بداية المستوى الجاي (undefined إذا أعلى مستوى)
        const start = d.levels[st.level - 1] || 0;
        const pct = next ? Math.min(100, ((st.xp - start) / (next - start)) * 100) : 100;
        const bonus = Math.floor(((1.0 + (st.level - 1) * d.bonusPerLevel) - 1) * 100); // نفس حساب السيرفر
        return { xp: st.xp, level: st.level, earned: st.earned, next, pct, bonus };
    }

    function distText(m) {
        return m >= 1000 ? (m / 1000).toFixed(1) + ' كم' : m + ' م';
    }

    // ---------------------------------------------------------------- نافذة التأكيد
    function confirmBox(title, text, yesLabel, onYes) {
        $('#ocMTitle').textContent = title;
        $('#ocMTxt').textContent = text;
        $('#ocMYes').textContent = yesLabel;
        $('#ocMYes').onclick = () => { $('#ocModal').classList.add('hidden'); onYes(); };
        $('#ocModal').classList.remove('hidden');
    }
    $('#ocMNo').addEventListener('click', () => $('#ocModal').classList.add('hidden'));

    // ---------------------------------------------------------------- الإجراءات
    async function refresh() {
        const fresh = await post('centerRefresh');
        if (fresh && fresh.jobs) {
            S.data = Object.assign(S.data, { employed: fresh.employed, duty: fresh.duty, gov: fresh.gov, jobs: fresh.jobs, board: fresh.board || [] });
        }
        render();
    }

    async function doApply(job) {
        if (S.busy) return;
        S.busy = true;
        const r = await post('centerApply', { job: job.id });
        S.busy = false;
        if (r && r.ok) {
            await refresh();
            S.tab = 'mine';
            render();
        }
    }

    function tryApply(job) {
        const d = S.data;
        if (d.employed && d.employed !== job.id) {
            const cur = jobInfo(d.employed);
            return confirmBox('تغيير الوظيفة', `راح تترك وظيفتك الحالية (${cur ? cur.label : d.employed}) وتتوظف بـ ${job.label}. خبرتك ومستواك بالوظيفة القديمة يبقون محفوظين.`, 'نعم، وظّفني', () => doApply(job));
        }
        if (d.gov) {
            return confirmBox('تحذير قبل التوظيف', `وظيفتك الحالية (${d.gov}) ورتبتك راح تنشال نهائياً وما ترجع إذا وظّفت بـ ${job.label}.`, 'نعم، وظّفني', () => doApply(job));
        }
        doApply(job);
    }

    function tryQuit() {
        const cur = jobInfo(S.data.employed);
        confirmBox('تأكيد الاستقالة', `راح تستقيل من ${cur ? cur.label : 'وظيفتك'}. خبرتك ومستواك يبقون محفوظين إذا رجعت لها.`, 'نعم، استقيل', async () => {
            const r = await post('centerQuit');
            if (r && r.ok) await refresh();
        });
    }

    const gps = (job) => post('centerGps', { job: job.id });

    // ---------------------------------------------------------------- العرض
    function renderMe() {
        const d = S.data;
        const me = $('#ocMe');
        const chip = $('#ocChip');
        me.replaceChildren();
        chip.replaceChildren();
        let status;
        if (d.employed && jobInfo(d.employed)) {
            const j = jobInfo(d.employed);
            const li = levelInfo(d.employed);
            me.append(el('b', '', `${j.label} • مستوى ${li.level}`), document.createTextNode(li.next ? `الخبرة ${li.xp} / ${li.next}` : 'أعلى مستوى'));
            status = `موظف ${j.label}`;
        } else if (d.gov) {
            me.append(el('b', '', d.gov), document.createTextNode('وظيفة حكومية'));
            status = d.gov;
        } else {
            me.append(el('b', '', 'عاطل'), document.createTextNode('ما عندك وظيفة'));
            status = 'عاطل';
        }
        chip.append(document.createTextNode('الحالة: '), el('b', '', status));
    }

    function viewJobs(v) {
        const d = S.data;
        const list = el('div', 'oc-list');
        d.list.forEach((j) => {
            const b = el('button', 'oc-job' + (S.sel === j.id ? ' sel' : ''));
            if (d.employed === j.id) b.append(el('span', 'oc-tag', 'وظيفتك'));
            b.append(el('div', 'oc-ic', j.emoji), el('b', '', j.label), el('small', '', j.desc));
            const st = d.jobs[j.id];
            const bits = [];
            if (j.top) bits.push(j.top);
            if (st && st.xp > 0) bits.push(`مستواك م${st.level}`);
            if (bits.length) b.append(el('div', 'oc-inc', bits.join(' • ')));
            b.addEventListener('click', () => { S.sel = j.id; render(); });
            list.append(b);
        });
        v.append(list);

        const j = jobInfo(S.sel) || d.list[0];
        const det = el('div', 'oc-detail');

        const dh = el('div', 'oc-dh');
        const dt = el('div');
        dt.append(el('h2', '', j.label), el('p', '', j.desc));
        dh.append(el('div', 'oc-ic', j.emoji), dt);
        det.append(dh);

        const facts = el('div', 'oc-facts');
        [[j.top || '—', j.top && j.top.includes('متر') ? 'الأجرة' : 'أعلى سعر بيع'], [distText(j.dist), 'بعده عنك']].forEach(([val, lbl]) => {
            const f = el('div', 'oc-fact');
            f.append(el('b', '', val), el('span', '', lbl));
            facts.append(f);
        });
        det.append(facts);

        const steps = el('div');
        steps.append(el('div', 'oc-sec', 'مراحل الوظيفة'));
        const flow = el('div', 'oc-flow');
        j.steps.forEach((s, i) => {
            const row = el('div', 'oc-step');
            row.append(el('i', '', String(i + 1)), document.createTextNode(s.label), el('em', '', s.level > 0 ? `مستوى ${s.level}` : '—'));
            flow.append(row);
        });
        steps.append(flow);
        det.append(steps);

        const tools = el('div');
        tools.append(el('div', 'oc-sec', 'الأدوات المطلوبة'));
        if (j.tools.length) {
            j.tools.forEach((t) => {
                const row = el('div', 'oc-tool');
                row.append(el('span', '', t.label), el('span', '', '$' + fmt(t.price)));
                tools.append(row);
            });
        } else {
            const row = el('div', 'oc-tool');
            row.append(el('span', '', 'ما تحتاج أدوات'), el('span', '', 'مجاناً'));
            tools.append(row);
        }
        det.append(tools);

        const act = el('div', 'oc-actions');
        const mine = d.employed === j.id;
        const apply = el('button', 'oc-btn', mine ? 'أنت موظف هنا' : 'قدّم الآن');
        apply.disabled = mine;
        apply.addEventListener('click', () => tryApply(j));
        const loc = el('button', 'oc-btn oc-ghost', '📍 حدد الموقع');
        loc.addEventListener('click', () => gps(j));
        act.append(apply, loc);
        det.append(act);
        v.append(det);
    }

    function viewMine(v) {
        const d = S.data;
        const wrap = el('div', 'oc-wrap');
        const j = d.employed && jobInfo(d.employed);
        if (!j) {
            const e = el('div', 'oc-empty');
            e.append(el('div', '', '💼'), document.createTextNode('ما عندك وظيفة حالياً'), document.createElement('br'), document.createTextNode('اختر وظيفة من تبويب «الوظائف» وقدّم عليها'));
            wrap.append(e);
            return v.append(wrap);
        }
        const li = levelInfo(j.id);

        const hero = el('div', 'oc-hero');
        const hi = el('div');
        hi.style.flex = '1';
        const bar = el('div', 'oc-xp');
        const fill = el('i');
        fill.style.width = li.pct + '%';
        bar.append(fill);
        hi.append(el('h2', '', j.label), el('p', '', `المستوى ${li.level} • الخبرة ${li.xp}${li.next ? ' / ' + li.next : ' (أعلى مستوى)'} • مكافأة دخل +${li.bonus}%`), bar);
        hero.append(el('div', 'oc-ic', j.emoji), hi);
        wrap.append(hero);

        const stats = el('div', 'oc-stats');
        [[li.level, 'المستوى'], [fmt(li.xp), 'الخبرة'], ['$' + fmt(li.earned), 'إجمالي الدخل'], ['+' + li.bonus + '%', 'مكافأة الدخل']].forEach(([val, lbl]) => {
            const s = el('div', 'oc-stat');
            s.append(el('b', '', String(val)), el('span', '', lbl));
            stats.append(s);
        });
        wrap.append(stats);

        const lv = el('div');
        lv.append(el('div', 'oc-sec', 'المستويات'));
        const chips = el('div', 'oc-lv');
        d.levels.forEach((x, i) => chips.append(el('span', i < li.level ? 'ok' : '', `م${i + 1} • ${fmt(x)} خبرة`)));
        lv.append(chips);
        wrap.append(lv);

        const act = el('div', 'oc-actions');
        const loc = el('button', 'oc-btn oc-ghost', '📍 موقع الشركة');
        loc.addEventListener('click', () => gps(j));
        const quit = el('button', 'oc-btn oc-red', 'الاستقالة');
        quit.addEventListener('click', tryQuit);
        act.append(loc, quit);
        wrap.append(act);
        v.append(wrap);
    }

    function viewBoard(v) {
        const rows = S.data.board || [];
        const wrap = el('div', 'oc-wrap');
        if (!rows.length) {
            wrap.append(el('div', 'oc-empty', 'ماكو متصدرين للحين، كن أول واحد!'));
            return v.append(wrap);
        }
        rows.forEach((r, i) => {
            const row = el('div', 'oc-row');
            row.append(el('div', 'oc-rank', String(i + 1)), el('div', 'oc-nm', r.name || '—'), el('div', 'oc-jb', r.job), el('div', 'oc-v', `م${r.level} • ${fmt(r.xp)} خبرة`));
            wrap.append(row);
        });
        v.append(wrap);
    }

    function render() {
        if (!S.data) return;
        $('#ocTitle').textContent = TITLES[S.tab];
        const v = $('#ocView');
        v.replaceChildren();
        ({ jobs: viewJobs, mine: viewMine, board: viewBoard })[S.tab](v);
        document.querySelectorAll('.oc-tab').forEach((t) => t.classList.toggle('on', t.dataset.tab === S.tab));
        renderMe();
    }

    // ---------------------------------------------------------------- فتح وإغلاق
    function openCenter(data) {
        S.data = data;
        S.data.jobs = S.data.jobs || {};
        S.data.board = S.data.board || [];
        S.data.list = S.data.list || [];
        S.tab = 'jobs';
        S.sel = (data.employed && jobInfo(data.employed)) ? data.employed : (S.data.list[0] && S.data.list[0].id);
        S.busy = false;
        S.open = true;
        $('#ocModal').classList.add('hidden');
        $('#center').classList.remove('hidden');
        render();
    }

    function closeCenter() {
        if (!S.open) return;
        S.open = false;
        $('#center').classList.add('hidden');
        $('#ocModal').classList.add('hidden');
        post('centerClose');
    }

    document.querySelectorAll('.oc-tab').forEach((t) => t.addEventListener('click', () => { S.tab = t.dataset.tab; render(); }));
    $('#ocClose').addEventListener('click', closeCenter);
    window.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || !S.open) return;
        if (!$('#ocModal').classList.contains('hidden')) return $('#ocModal').classList.add('hidden');
        closeCenter();
    });
    window.addEventListener('message', ({ data }) => {
        if (!data || !data.action) return;
        if (data.action === 'centerOpen') openCenter(data.data);
        else if (data.action === 'centerClose') closeCenter();
    });
})();
