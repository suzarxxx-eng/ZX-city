// قائمة البيع على يمين الشاشة. الأسماء تدخل بـ textContent. الصورة تتجرب بالترتيب: صورة الغرض بالمخزن، الصورة الجاهزة، الرسم، ثم رمز
(function () {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'og_jobs';
    const $ = (s) => document.querySelector(s);
    const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
    }).catch(() => null);
    const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
    const fmt = (n) => Number(n || 0).toLocaleString('en-US');

    let open = false, list = [];

    function icon(e) {
        const box = el('div', 'sp-ic');
        const srcs = [];
        if (e.image) srcs.push(`nui://qb-inventory/html/images/${e.image}`);
        if (e.alt) srcs.push(`nui://qb-inventory/html/images/${e.alt}`);
        srcs.push(`img/${e.item}.svg`);
        const img = el('img');
        let i = 0;
        img.onerror = () => { i++; if (i < srcs.length) img.src = srcs[i]; else img.replaceWith(el('span', '', '📦')); };
        img.src = srcs[0];
        box.append(img, el('i', '', '×' + e.count));
        return box;
    }

    function render() {
        const box = $('#spList');
        box.replaceChildren();
        if (!list.length) {
            box.append(el('div', 'sp-empty', 'ماعندك شي تبيعه هنا'));
        }
        let total = 0;
        list.forEach((e) => {
            total += e.price * e.count;
            const b = el('button', 'sp-item');
            const nm = el('div', 'sp-nm');
            nm.append(el('b', '', e.label), el('small', '', `$${fmt(e.price)} للحبة`));
            b.append(icon(e), nm, el('div', 'sp-tot', '$' + fmt(e.price * e.count)));
            b.addEventListener('click', () => post('sellItem', { stage: e.stage, item: e.item }));
            box.append(b);
        });
        const all = $('#spAll');
        all.textContent = list.length ? `بيع الكل • $${fmt(total)}` : 'بيع الكل';
        all.disabled = !list.length;
    }

    function close() {
        if (!open) return;
        open = false;
        $('#sellpanel').classList.add('hidden');
        post('sellClose');
    }

    $('#spAll').addEventListener('click', () => {
        const stages = [...new Set(list.map((e) => e.stage))];
        if (stages.length) post('sellAll', { stages });
    });
    $('#spClose').addEventListener('click', close);
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
    window.addEventListener('message', ({ data }) => {
        if (!data || !data.action) return;
        if (data.action === 'sellOpen') {
            open = true;
            list = data.list || [];
            $('#spTitle').textContent = data.title || '';
            $('#sellpanel').classList.remove('hidden');
            render();
        } else if (data.action === 'sellUpdate') {
            list = data.list || [];
            render();
        }
    });
})();
