-- وظيفة الخشاب: قطع الأشجار ← نشر ← بيع
-- ملاحظة: الإحداثيات تقريبية (غابة بليتو). عدّلها حسب الخريطة عندك.
Config.Jobs['lumberjack'] = {
    label = 'الخشاب',
    icon = 'fas fa-tree',
    emoji = '🌲',
    desc = 'اقطع الأشجار وانشر الخشب وبيعه',
    boss = {
        model = 's_m_y_construct_01',
        coords = vector4(-552.70, 5348.20, 74.74, 70.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 473, color = 69, scale = 0.9 }, -- أيقونة تسجيل الدخول (تظهر للموظف بهذي الوظيفة فقط)
    },
    -- نقطة البيع: رصيف التسليم الخلفي لمتجر العدد والأدوات (باي هاردوير) ببليتو، الخشب ينباع لمتجر مواد البناء
    -- z = مستوى الأرض (ينلقى تلقائياً). لتغيير المكان باللعبة: قف بالمكان الجديد واكتب /jobsell الخشاب
    sell = {
        coords = vector4(-438.25, 6146.90, 31.00, 237.0),
        model = 'mp_m_waremech_01', scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    tools = {
        { item = 'axe', label = 'فأس', price = 150 },
    },
    stages = {
        {
            type = 'gather', label = 'قطع شجرة', icon = 'fas fa-tree',
            points = {
                { coords = vector3(-549.0, 5424.0, 64.0), radius = 35.0 },
                { coords = vector3(-510.0, 5470.0, 65.0), radius = 30.0 },
            },
            requireItem = 'axe', time = 7000, minLevel = 1,
            scenario = 'WORLD_HUMAN_HAMMERING',
            give = { item = 'log', min = 1, max = 2 }, xp = 4,
        },
        {
            type = 'process', label = 'نشر الخشب', icon = 'fas fa-gears',
            station = { model = 's_m_y_construct_02', coords = vector4(-538.40, 5339.50, 71.00, 340.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'log', amount = 2 }, give = { item = 'plank', amount = 1 },
            time = 6000, minLevel = 1, scenario = 'PROP_HUMAN_BUM_BIN', xp = 3,
        },
        {
            type = 'sell', label = 'بيع الأخشاب', icon = 'fas fa-sack-dollar',
            prices = { plank = 60, log = 20 },
        },
    },
}
