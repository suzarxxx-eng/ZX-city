-- وظيفة التنقيب: حفر معادن ← صهر ← بيع
-- أدوات (تنشترى من قائمة الوظيفة): فأس ← دريل حفر ← دريل متطور (كل واحدة أسرع وتفتح معادن أكثر)
-- أيقونات الوظيفة بالخريطة تظهر فقط لمن يسجل دخول: أضفها بالأمر /jobblip (شوف الشرح بـ config.lua)
-- ملاحظة: الإحداثيات تقريبية (محجر السنورا). عدّلها حسب الخريطة عندك.
Config.Jobs['mining'] = {
    label = 'التنقيب عن المعادن',
    icon = 'fas fa-gem',
    emoji = '💎',
    desc = 'احفر حديد ونحاس وذهب وصهرها وبيعها',
    boss = {
        model = 's_m_y_construct_01',
        coords = vector4(2955.90, 2745.90, 43.50, 290.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 527, color = 5, scale = 0.9 }, -- أيقونة تسجيل الدخول (تظهر للموظف بهذي الوظيفة فقط)
    },
    blips = {}, -- أيقونات الخريطة (تظهر بعد تسجيل الدخول فقط)
    -- نقطة البيع: ساحة تحميل محجر ديفيس كوارتز (المعادن تنباع هناك). هذا المكان انحدد بـ /jobsell (sells.json)
    sell = {
        coords = vector4(2662.44, 2899.12, 35.32, 19.84),
        noPed = true, radius = 4.0, distance = 4.0, -- بدون موظف: البيع من باب الكابينة (صوّب على الباب)
    },
    tools = {
        { item = 'pickaxe',        label = 'فأس',        price = 200 },
        { item = 'mining_drill',   label = 'دريل حفر',   price = 900 },
        { item = 'advanced_drill', label = 'دريل متطور', price = 2500 },
    },
    stages = {
        {
            type = 'gather', label = 'حفر حديد', icon = 'fas fa-hill-rockslide',
            points = { { coords = vector3(2970.0, 2740.0, 43.0), radius = 18.0 } },
            -- كل أداة بوقت حفر وإضافة كمية (bonus). السيرفر يختار أفضل أداة تملكها من هذي
            tiers = {
                pickaxe        = { time = 7000, bonus = 0 },
                mining_drill   = { time = 5000, bonus = 1 },
                advanced_drill = { time = 3500, bonus = 2 },
            },
            minLevel = 1, scenario = 'WORLD_HUMAN_CONST_DRILL',
            give = { item = 'iron_ore', min = 1, max = 3 }, xp = 4,
        },
        {
            type = 'gather', label = 'حفر نحاس', icon = 'fas fa-hill-rockslide',
            points = { { coords = vector3(2995.0, 2765.0, 43.0), radius = 18.0 } },
            tiers = { -- الفأس ما يحفر نحاس: تحتاج دريل
                mining_drill   = { time = 6000, bonus = 0 },
                advanced_drill = { time = 4000, bonus = 1 },
            },
            minLevel = 3, scenario = 'WORLD_HUMAN_CONST_DRILL',
            give = { item = 'copper_ore', min = 1, max = 2 }, xp = 6,
        },
        {
            type = 'gather', label = 'حفر ذهب', icon = 'fas fa-hill-rockslide',
            points = { { coords = vector3(2940.0, 2790.0, 43.0), radius = 18.0 } },
            tiers = { -- الذهب بس بالدريل المتطور
                advanced_drill = { time = 6000, bonus = 0 },
            },
            minLevel = 5, scenario = 'WORLD_HUMAN_CONST_DRILL',
            give = { item = 'gold_ore', min = 1, max = 2 }, xp = 10,
        },
        {
            type = 'process', label = 'صهر الحديد', icon = 'fas fa-fire',
            station = { model = 's_m_y_construct_02', coords = vector4(2927.80, 2717.70, 43.50, 20.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'iron_ore', amount = 2 }, give = { item = 'iron_bar', amount = 1 },
            time = 6000, minLevel = 1, scenario = 'PROP_HUMAN_BUM_BIN', xp = 3,
        },
        {
            type = 'process', label = 'صهر النحاس', icon = 'fas fa-fire',
            station = { model = 's_m_y_construct_02', coords = vector4(2927.80, 2717.70, 43.50, 20.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'copper_ore', amount = 2 }, give = { item = 'copper_bar', amount = 1 },
            time = 7000, minLevel = 3, scenario = 'PROP_HUMAN_BUM_BIN', xp = 5,
        },
        {
            type = 'process', label = 'صهر الذهب', icon = 'fas fa-fire',
            station = { model = 's_m_y_construct_02', coords = vector4(2927.80, 2717.70, 43.50, 20.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'gold_ore', amount = 2 }, give = { item = 'gold_bar', amount = 1 },
            time = 9000, minLevel = 5, scenario = 'PROP_HUMAN_BUM_BIN', xp = 8,
        },
        {
            type = 'sell', label = 'بيع المعادن', icon = 'fas fa-sack-dollar',
            prices = { iron_bar = 90, copper_bar = 160, gold_bar = 450, iron_ore = 25, copper_ore = 45, gold_ore = 120 },
        },
    },
}
