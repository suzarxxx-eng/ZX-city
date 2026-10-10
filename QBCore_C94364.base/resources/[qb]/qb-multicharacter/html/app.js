const post = (name, data) =>
    fetch(`https://qb-multicharacter/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data || {}),
    })
        .then((r) => r.json())
        .catch(() => ({}));

const sl = (key, label, min = -10, max = 10, stepBy = 1) => ({ type: "slider", id: key, key, label, min, max, stepBy });
const st = (key, field, label) => ({ type: "step", id: key + field, key, field, label });

const TABS = [
    {
        id: "origin",
        label: "الأصل",
        groups: [
            {
                title: "الوراثة",
                rows: [
                    st("face", "item", "ملامح الأب"),
                    st("face2", "item", "ملامح الأم"),
                    sl("shapeMix", "الشبه بالأب ← الأم", 0, 1, 0.01),
                    st("face", "texture", "بشرة الأب"),
                    st("face2", "texture", "بشرة الأم"),
                    sl("skinMix", "درجة البشرة", 0, 1, 0.01),
                ],
            },
            {
                title: "الشعر واللحية",
                rows: [
                    st("hair", "item", "تسريحة الشعر"),
                    st("hair", "texture", "لون الشعر"),
                    st("beard", "item", "اللحية"),
                    st("beard", "texture", "لون اللحية"),
                    st("eyebrows", "item", "الحواجب"),
                    st("eyebrows", "texture", "لون الحواجب"),
                ],
            },
            {
                title: "تفاصيل",
                rows: [st("eye_color", "item", "لون العين"), st("ageing", "item", "التجاعيد"), st("makeup", "item", "مكياج"), st("lipstick", "item", "أحمر شفاه"), st("blush", "item", "أحمر خدود")],
            },
        ],
    },
    {
        id: "face",
        label: "الوجه",
        groups: [
            { title: "الأنف", rows: [sl("nose_0", "عرض الأنف"), sl("nose_1", "ارتفاع الأنف"), sl("nose_2", "طول الأنف"), sl("nose_3", "عظم الأنف"), sl("nose_4", "رأس الأنف"), sl("nose_5", "انحراف الأنف")] },
            { title: "العيون والحواجب", rows: [sl("eye_opening", "فتحة العين"), sl("eyebrown_high", "ارتفاع الحواجب"), sl("eyebrown_forward", "بروز الحواجب")] },
            { title: "الخدود والشفايف", rows: [sl("cheek_1", "عظام الخد"), sl("cheek_2", "عرض الخد"), sl("cheek_3", "امتلاء الخد"), sl("lips_thickness", "الشفايف")] },
            { title: "الفك والذقن", rows: [sl("jaw_bone_width", "عرض الفك"), sl("jaw_bone_back_lenght", "طول الفك"), sl("chimp_bone_lowering", "ارتفاع الذقن"), sl("chimp_bone_lenght", "طول الذقن"), sl("chimp_bone_width", "عرض الذقن"), sl("chimp_hole", "شق الذقن"), sl("neck_thikness", "سمك الرقبة")] },
        ],
    },
    {
        id: "clothes",
        label: "الملابس",
        groups: [
            {
                title: "الأساسي",
                rows: [st("torso2", "item", "الجاكيت / الأعلى"), st("torso2", "texture", "لون الأعلى"), st("t-shirt", "item", "القميص الداخلي"), st("t-shirt", "texture", "لون القميص"), st("arms", "item", "الأذرع (تناسب الأعلى)"), st("pants", "item", "البنطلون"), st("pants", "texture", "لون البنطلون"), st("shoes", "item", "الحذاء"), st("shoes", "texture", "لون الحذاء")],
            },
            {
                title: "إكسسوارات",
                rows: [st("hat", "item", "قبعة"), st("hat", "texture", "لون القبعة"), st("glass", "item", "نظارة"), st("glass", "texture", "لون النظارة"), st("watch", "item", "ساعة"), st("bracelet", "item", "سوار"), st("ear", "item", "حلق / سماعة"), st("accessory", "item", "سلسلة / وشاح"), st("bag", "item", "شنطة"), st("mask", "item", "كمامة / قناع")],
            },
        ],
    },
];

document.addEventListener("DOMContentLoaded", () => {
    new Vue({
        el: "#app",
        data: {
            characters: [],
            show: { loading: false, main: false, register: false, creator: false, delete: false },
            registerData: { date: "2000-01-01", firstname: "", lastname: "", nationality: "", gender: "male" },
            allowDelete: false,
            loadingText: "",
            dollar: Intl.NumberFormat("en-US"),
            customNationality: false,
            nationalities: [],
            tabs: TABS,
            tab: 0,
            open: 0,
            scenes: [],
            scene: "",
            view: { zoom: 0, height: 0.5, rot: 0 },
            states: {},
            sliders: {},
            dragging: false,
            lastX: 0,
        },
        computed: {
            mainChar() {
                return Object.values(this.characters).find(Boolean);
            },
            dockVisible() {
                return this.show.main || this.show.register || this.show.creator;
            },
        },
        methods: {
            translate(key, params) {
                return params ? translationManager.formatTranslation(key, params) : translationManager.translate(key);
            },
            showMain() {
                this.show.register = false;
                this.show.creator = false;
                this.show.delete = false;
                this.show.main = true;
                post("cDataPed", this.mainChar ? { cData: this.mainChar } : {});
            },
            play_character() {
                if (!this.mainChar) return;
                post("selectCharacter", { cData: this.mainChar });
                this.show.main = false;
            },
            prepareDelete() {
                this.show.main = false;
                this.show.delete = true;
            },
            cancelDelete() {
                this.show.delete = false;
                this.show.main = true;
            },
            delete_character() {
                this.show.delete = false;
                post("removeCharacter", { citizenid: this.mainChar.citizenid });
                setTimeout(() => (this.show.main = true), 500);
            },
            startRegister() {
                this.registerData = { date: "2000-01-01", firstname: "", lastname: "", nationality: "", gender: "male" };
                this.show.main = false;
                this.show.register = true;
            },
            cancelCreate() {
                this.show.register = false;
                this.show.main = true;
                post("cDataPed", {});
            },
            validate() {
                const d = this.registerData;
                return characterValidator.validateCharacter({ firstname: d.firstname, lastname: d.lastname, nationality: d.nationality, gender: d.gender, date: d.date });
            },
            fail(result) {
                Swal.fire({
                    icon: "error",
                    title: this.translate("ran_into_issue"),
                    text: this.translate(result.message, { field: this.translate(result.field) }),
                    timer: 5000,
                    timerProgressBar: true,
                    showConfirmButton: false,
                });
            },
            async toCreator() {
                const result = this.validate();
                if (!result.isValid) return this.fail(result);
                this.show.register = false;
                this.tab = 0;
                this.open = 0;
                this.sliders = { shapeMix: 0.5, skinMix: 0.5 };
                TABS.forEach((t) => t.groups.forEach((g) => g.rows.forEach((r) => r.type === "slider" && r.id !== "shapeMix" && r.id !== "skinMix" && this.$set(this.sliders, r.key, 0))));
                await post("creatorStart", { gender: this.registerData.gender === "female" ? 1 : 0 });
                await this.refreshStates();
                this.show.creator = true;
            },
            async refreshStates() {
                const keys = new Set();
                TABS.forEach((t) => t.groups.forEach((g) => g.rows.forEach((r) => r.type === "step" && keys.add(r.key))));
                for (const key of keys) {
                    this.$set(this.states, key, await post("creatorState", { key }));
                }
            },
            backToRegister() {
                this.show.creator = false;
                this.show.register = true;
            },
            async step(r, delta) {
                const res = await post("creatorStep", { key: r.key, field: r.field, delta });
                this.$set(this.states, r.key, res);
            },
            stepText(r) {
                const s = this.states[r.key];
                if (!s || s[r.field] === undefined) return "—";
                const v = s[r.field];
                if (r.field === "item" && s.minItem === -1 && v === -1) return "بدون";
                const max = r.field === "item" ? s.maxItem : s.maxTexture;
                return `${v} / ${max}`;
            },
            slide(r) {
                post("creatorSlider", { key: r.key, value: this.sliders[r.key] });
            },
            setView(part) {
                Object.assign(this.view, part);
                post("viewSet", part);
            },
            nudge(part, amount, lo, hi) {
                const v = Math.min(hi, Math.max(lo, this.view[part] + amount));
                this.setView({ [part]: Math.round(v * 100) / 100 });
            },
            preset(name) {
                if (name === "body") this.setView({ zoom: 0, height: 0.5 });
                if (name === "half") this.setView({ zoom: 0.55, height: 0.62 });
                if (name === "face") this.setView({ zoom: 1, height: 1 });
            },
            async resetView() {
                this.view = await post("viewReset");
            },
            pickScene(id) {
                this.scene = id;
                post("setScene", { id });
            },
            toggleGroup(i) {
                this.open = this.open === i ? -1 : i;
            },
            onKey(e) {
                if (!this.dockVisible || e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
                if (e.key === "ArrowLeft" || e.key === "a") this.nudge("rot", -12, -360, 360);
                if (e.key === "ArrowRight" || e.key === "d") this.nudge("rot", 12, -360, 360);
                if (e.key === "ArrowUp" || e.key === "w") this.nudge("zoom", 0.06, 0, 1);
                if (e.key === "ArrowDown" || e.key === "s") this.nudge("zoom", -0.06, 0, 1);
            },
            async randomize() {
                await post("creatorRandom");
                await this.refreshStates();
            },
            create_character() {
                const result = this.validate();
                if (!result.isValid) return this.fail(result);
                const d = this.registerData;
                this.show.creator = false;
                post("createNewCharacter", { firstname: d.firstname, lastname: d.lastname, nationality: d.nationality, birthdate: d.date, gender: d.gender, cid: 1 });
            },
            dragStart(e) {
                if (this.dockVisible && e.target.closest(".panel, .dock, .scenes") === null) {
                    this.dragging = true;
                    this.lastX = e.clientX;
                }
            },
            dragEnd() {
                this.dragging = false;
            },
            dragMove(e) {
                if (!this.dragging) return;
                const dx = e.clientX - this.lastX;
                if (Math.abs(dx) >= 2) {
                    this.view.rot += dx * 0.7;
                    this.setView({ rot: Math.round(this.view.rot) });
                    this.lastX = e.clientX;
                }
            },
            wheel(e) {
                if (!this.dockVisible || e.target.closest(".panel")) return;
                this.nudge("zoom", e.deltaY < 0 ? 0.07 : -0.07, 0, 1);
            },
        },
        mounted() {
            initializeValidator();
            window.addEventListener("keydown", this.onKey);
            let loadingProgress = 0;
            window.addEventListener("message", (event) => {
                const data = event.data;
                switch (data.action) {
                    case "ui":
                        this.customNationality = data.customNationality;
                        translationManager.setTranslations(data.translations);
                        this.nationalities = data.countries;
                        this.scenes = data.scenes || [];
                        this.scene = this.scenes.length ? this.scenes[0].id : "";
                        this.view = { zoom: 0, height: 0.5, rot: 0 };
                        this.show.register = false;
                        this.show.creator = false;
                        this.show.delete = false;
                        this.show.main = false;
                        this.allowDelete = data.enableDeleteButton;
                        if (data.toggle) {
                            this.show.loading = true;
                            this.loadingText = this.translate("retrieving_playerdata");
                            const interval = setInterval(() => {
                                loadingProgress++;
                                if (loadingProgress == 2) this.loadingText = this.translate("retrieving_characters");
                                if (loadingProgress == 4) this.loadingText = this.translate("validating_characters");
                            }, 500);
                            setTimeout(() => {
                                post("setupCharacters");
                                setTimeout(() => {
                                    clearInterval(interval);
                                    loadingProgress = 0;
                                    this.show.loading = false;
                                    this.showMain();
                                    post("removeBlur");
                                }, 2000);
                            }, 2000);
                        }
                        break;
                    case "setupCharacters": {
                        const newChars = [];
                        for (let i = 0; i < data.characters.length; i++) newChars[data.characters[i].cid] = data.characters[i];
                        this.characters = newChars;
                        break;
                    }
                }
            });
        },
    });
});
