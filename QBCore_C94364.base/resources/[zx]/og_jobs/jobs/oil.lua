-- شركة النفط: استخراج ← تكرير ← تسليم
-- ملاحظة: الإحداثيات تقريبية (حقل نفط مورييتا). عدّلها حسب الخريطة عندك.
Config.Jobs['oil'] = {
    label = 'شركة النفط',
    icon = 'fas fa-oil-well',
    emoji = '🛢️',
    desc = 'استخرج النفط وكرره وسلّم البراميل',
    boss = {
        model = 's_m_y_construct_01',
        coords = vector4(1722.40, -1636.90, 112.60, 190.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 361, color = 40, scale = 0.9 }, -- أيقونة تسجيل الدخول (تظهر للموظف بهذي الوظيفة فقط)
    },
    -- نقطة التسليم: محطة وقود Ron على كابيتال بوليفارد (أقرب محطة لحقل النفط، البراميل تنسلّم للمحطة)
    -- z = مستوى الأرض (ينلقى تلقائياً). لتغيير المكان باللعبة: قف بالمكان الجديد واكتب /jobsell النفط
    sell = {
        coords = vector4(1211.13, -1389.18, 34.38, 177.39),
        model = 's_m_y_construct_01', scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    tools = {},
    stages = {
        {
            type = 'gather', label = 'استخراج النفط', icon = 'fas fa-oil-well',
            points = { { coords = vector3(1745.2, -1625.6, 112.6), radius = 20.0 } },
            time = 8000, minLevel = 1,
            scenario = 'WORLD_HUMAN_WELDING',
            give = { item = 'crude_oil', min = 1, max = 2 }, xp = 4,
        },
        {
            type = 'process', label = 'تكرير النفط', icon = 'fas fa-industry',
            station = { model = 's_m_y_construct_02', coords = vector4(1710.00, -1650.00, 112.60, 100.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'crude_oil', amount = 2 }, give = { item = 'fuel_barrel', amount = 1 },
            time = 7000, minLevel = 1, scenario = 'PROP_HUMAN_BUM_BIN', xp = 5,
        },
        {
            type = 'sell', label = 'تسليم البراميل', icon = 'fas fa-truck',
            prices = { fuel_barrel = 140, crude_oil = 45 },
        },
    },
}
