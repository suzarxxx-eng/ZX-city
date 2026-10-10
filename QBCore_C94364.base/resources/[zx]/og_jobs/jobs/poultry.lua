-- شركة الدواجن: جمع دجاج ← ذبح ← تغليف ← بيع
-- ملاحظة: الإحداثيات تقريبية (مزرعة بليتو). عدّلها حسب الخريطة عندك.
Config.Jobs['poultry'] = {
    label = 'شركة الدواجن',
    icon = 'fas fa-drumstick-bite',
    emoji = '🍗',
    desc = 'اجمع الدجاج واذبحه وغلّفه وبيعه',
    boss = {
        model = 'a_m_m_farmer_01',
        coords = vector4(-84.50, 6247.30, 31.10, 130.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 556, color = 47, scale = 0.9 }, -- أيقونة تسجيل الدخول (تظهر للموظف بهذي الوظيفة فقط)
    },
    -- نقطة البيع: باب التوريد الخلفي لسوبرماركت 24/7 ببليتو (اللحم المعبأ ينباع للسوبرماركت). المسافة حوالي 1.8 كم من المزرعة
    -- بديل أقرب: ساحة مصنع كلوكن بيل الجنوبية (-155.50, 6139.77, 30.34). لتغيير المكان باللعبة: قف بالمكان الجديد واكتب /jobsell الدواجن
    sell = {
        coords = vector4(1743.26, 6419.61, 34.04, 280.0),
        model = 's_m_y_chef_01', scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    tools = {},
    stages = {
        {
            type = 'gather', label = 'جمع الدجاج', icon = 'fas fa-feather',
            points = { { coords = vector3(-72.0, 6262.0, 31.1), radius = 25.0 } },
            time = 5000, minLevel = 1,
            scenario = 'WORLD_HUMAN_GARDENER_PLANT',
            give = { item = 'chicken_live', min = 1, max = 2 }, xp = 3,
        },
        {
            type = 'process', label = 'ذبح الدجاج', icon = 'fas fa-knife-kitchen',
            station = { model = 's_m_y_chef_01', coords = vector4(-100.50, 6205.40, 31.00, 40.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'chicken_live', amount = 2 }, give = { item = 'chicken_meat', amount = 2 },
            time = 6000, minLevel = 1, scenario = 'PROP_HUMAN_BUM_BIN', xp = 3,
        },
        {
            type = 'process', label = 'تغليف اللحم', icon = 'fas fa-box',
            station = { model = 's_m_y_chef_01', coords = vector4(-108.40, 6202.40, 31.00, 40.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
            take = { item = 'chicken_meat', amount = 2 }, give = { item = 'chicken_pack', amount = 1 },
            time = 5000, minLevel = 2, scenario = 'PROP_HUMAN_BUM_BIN', xp = 4,
        },
        {
            type = 'sell', label = 'بيع اللحم المعبأ', icon = 'fas fa-sack-dollar',
            prices = { chicken_pack = 85, chicken_meat = 35 },
        },
    },
}
