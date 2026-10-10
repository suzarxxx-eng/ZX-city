-- وظيفة صيد الأسماك: صيد ← تنظيف ← بيع
-- ملاحظة: الإحداثيات تقريبية (رصيف ديل بيرو). عدّلها حسب الخريطة عندك.
Config.Jobs['fishing'] = {
    label = 'صيد الأسماك',
    icon = 'fas fa-fish',
    emoji = '🐟',
    desc = 'اصطاد من الرصيف ونظف السمك وبيعه',
    boss = {
        model = 'a_m_m_farmer_01',
        coords = vector4(-1816.70, -1193.70, 14.31, 330.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 410, color = 3, scale = 0.9 }, -- أيقونة تسجيل الدخول (تظهر للموظف بهذي الوظيفة فقط)
    },
    -- نقطة البيع: رصيف التحميل عند مدخل رصيف ديل بيرو بجنب متجر «عالم البحار» (السمك ينباع لمتجر البحر)
    -- z = مستوى الأرض (ينلقى تلقائياً). لتغيير المكان باللعبة: قف بالمكان الجديد واكتب /jobsell الصيد
    sell = {
        coords = vector4(-1674.18, -1073.70, 12.15, 333.56),
        model = 's_m_y_dockwork_01', scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    tools = {
        { item = 'fishingrod', label = 'صنارة صيد', price = 120 },
    },
    stages = {
        {
            type = 'gather', label = 'رمي الصنارة', icon = 'fas fa-fish',
            points = {
                { coords = vector3(-1850.0, -1252.0, 8.6), radius = 10.0 },
                { coords = vector3(-1826.0, -1272.0, 8.6), radius = 10.0 },
            },
            requireItem = 'fishingrod', time = 10000, minLevel = 1,
            scenario = 'WORLD_HUMAN_STAND_FISHING',
            give = { item = 'fish_catch', min = 1, max = 2 }, xp = 4,
        },
        {
            type = 'process', label = 'تنظيف السمك', icon = 'fas fa-knife-kitchen',
            station = { model = 'a_m_m_farmer_01', coords = vector4(-1811.50, -1191.50, 14.31, 150.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'fish_catch', amount = 2 }, give = { item = 'fish_fillet', amount = 2 },
            time = 5000, minLevel = 1, scenario = 'PROP_HUMAN_BUM_BIN', xp = 3,
        },
        {
            type = 'sell', label = 'بيع السمك', icon = 'fas fa-sack-dollar',
            prices = { fish_fillet = 55, fish_catch = 25 },
        },
    },
}
