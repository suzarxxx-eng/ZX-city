Config = {}

-- ===================== الطاولة (ورشة OG) =====================
-- الطاولة: طاولة حديد سودة بيها لوحة عدة وضوء (من ورشة الأسلحة باللعبة)
-- الأماكن مخفية (بدون علامة بالخريطة). تضيف طاولة: وقف بالمكان واكتب  /ogcraftadd   وتشيل أقربها:  /ogcraftremove
-- إذا الطاولة طلعت ظهرها إلك:  /ogcraftrotate  (يلفها 90 درجة)
Config.Distance = 2.2          -- مسافة العين
Config.ServerDistance = 6.0    -- السيرفر يتأكد اللاعب يم الطاولة
Config.Blips = false           -- مخفية: بدون علامة بالخريطة
Config.Title = 'ورشة OG'
-- الطاولات الثابتة (ما تتغير حتى بعد الريستارت). x, y, z (أسفل الطاولة), اتجاه
Config.Tables = {
    { label = 'ورشة OG', coords = vector4(756.5253, -933.2368, 24.1379, 7.0866) },
}

Config.Station = {
    bench = { `gr_prop_gr_bench_04b`, `gr_prop_gr_bench_04a`, `prop_tool_bench02` }, -- أول واحد موجود
    front = 180.0,                           -- لفة الموديل حتى وجه الطاولة يصير إلك
    glow = { r = 255, g = 150, b = 40 },     -- ضوء برتقالي خفيف فوك الطاولة
}

-- ===================== المستويات (0 - 12) =====================
Config.Levels = {
    [0]  = { xp = 0,    name = 'مبتدئ' },
    [1]  = { xp = 100,  name = 'متدرب' },
    [2]  = { xp = 250,  name = 'صانع' },
    [3]  = { xp = 450,  name = 'حرفي' },
    [4]  = { xp = 700,  name = 'ماهر' },
    [5]  = { xp = 1000, name = 'محترف' },
    [6]  = { xp = 1400, name = 'خبير' },
    [7]  = { xp = 1900, name = 'متمرس' },
    [8]  = { xp = 2500, name = 'أستاذ' },
    [9]  = { xp = 3200, name = 'نخبة' },
    [10] = { xp = 4000, name = 'زعيم' },
    [11] = { xp = 5000, name = 'أسطورة' },
    [12] = { xp = 6500, name = 'أسطورة OG' },
}
Config.MaxLevel = 12
Config.SpeedPerLevel = 0.04    -- كل مستوى يسرع التصنيع 4%
Config.MaxQty = 10
Config.MetaKey = 'ogcraft'

-- ===================== المخطوطات =====================
-- الأسلحة النارية تحتاج مخطوطة (blueprint_<اسم السلاح>) وتنصرف وحدة لكل سلاح
-- تطلع بس من سرقات البيوت والمحلات، بنسبة قليلة جداً
-- الأسلحة النارية بالطاولة بس أسلحة العصابات (8). الأسلحة المتطورة للعساكر بس
Config.Blueprints = {
    cats = { pistol = true, smg = true, shotgun = true, rifle = true, sniper = true },
    sources = {                       -- السكربت: نسبة الحصول (0.02 = 2%)
        ['qb-houserobbery'] = 0.02,
        ['qb-storerobbery'] = 0.03,
    },
    cooldown = 300,                   -- ثواني: نفس اللاعب ما يحصل فرصة ثانية من نفس السرقة قبلها
}

-- ===================== الأقسام =====================
Config.Categories = {
    { id = 'rob',     label = 'أدوات السرقة', icon = 'lock' },
    { id = 'cuffs',   label = 'أصفاد ودروع',  icon = 'cuffs' },
    { id = 'melee',   label = 'أسلحة بيضاء',  icon = 'knife' },
    { id = 'pistol',  label = 'مسدسات',       icon = 'gun' },
    { id = 'smg',     label = 'رشاشات خفيفة', icon = 'smg' },
    { id = 'shotgun', label = 'شوزن',         icon = 'shotgun' },
    { id = 'rifle',   label = 'رشاشات',       icon = 'rifle' },
    { id = 'sniper',  label = 'قناص',         icon = 'scope' },
    { id = 'ammo',    label = 'ذخيرة',        icon = 'ammo' },
    { id = 'attach',  label = 'ملحقات',       icon = 'attach' },
}

-- ===================== الوصفات =====================
-- item = الغرض   level = المستوى المطلوب   xp = الخبرة   time = ثواني   amount = كم يطلع   mats = المواد
Config.Recipes = {
    -- أدوات السرقة
    { item = 'lockpick',         cat = 'rob', level = 0,  xp = 6,  time = 5,  mats = { { 'metalscrap', 8 }, { 'plastic', 6 } } },
    { item = 'screwdriverset',   cat = 'rob', level = 0,  xp = 8,  time = 6,  mats = { { 'metalscrap', 12 }, { 'plastic', 10 } } },
    { item = 'electronickit',    cat = 'rob', level = 1,  xp = 14, time = 9,  mats = { { 'copper', 14 }, { 'plastic', 12 }, { 'aluminum', 8 } } },
    { item = 'advancedlockpick', cat = 'rob', level = 2,  xp = 18, time = 10, mats = { { 'lockpick', 2 }, { 'steel', 12 }, { 'aluminum', 8 } } },
    { item = 'radioscanner',     cat = 'rob', level = 3,  xp = 22, time = 12, mats = { { 'electronickit', 1 }, { 'copper', 15 }, { 'plastic', 12 } } },
    { item = 'ironoxide',        cat = 'rob', level = 4,  xp = 18, time = 10, mats = { { 'iron', 40 }, { 'glass', 20 } } },
    { item = 'aluminumoxide',    cat = 'rob', level = 4,  xp = 18, time = 10, mats = { { 'aluminum', 40 }, { 'glass', 20 } } },
    { item = 'gatecrack',        cat = 'rob', level = 4,  xp = 30, time = 15, mats = { { 'electronickit', 2 }, { 'aluminum', 25 }, { 'plastic', 30 } } },
    { item = 'trojan_usb',       cat = 'rob', level = 5,  xp = 38, time = 18, mats = { { 'electronickit', 3 }, { 'plastic', 20 }, { 'copper', 20 } } },
    { item = 'thermite',         cat = 'rob', level = 6,  xp = 40, time = 18, mats = { { 'ironoxide', 3 }, { 'aluminumoxide', 3 } } },
    { item = 'drill',            cat = 'rob', level = 6,  xp = 45, time = 22, mats = { { 'iron', 50 }, { 'steel', 50 }, { 'screwdriverset', 2 } } },
    { item = 'laptop',           cat = 'rob', level = 7,  xp = 50, time = 22, mats = { { 'electronickit', 4 }, { 'plastic', 40 }, { 'glass', 15 } } },

    -- أصفاد ودروع
    { item = 'handcuffs',  cat = 'cuffs', level = 2, xp = 22, time = 12, mats = { { 'steel', 20 }, { 'metalscrap', 14 } } },
    { item = 'armor',      cat = 'cuffs', level = 3, xp = 26, time = 14, mats = { { 'steel', 30 }, { 'plastic', 25 }, { 'rubber', 15 } } },
    { item = 'heavyarmor', cat = 'cuffs', level = 7, xp = 45, time = 20, mats = { { 'armor', 1 }, { 'steel', 40 }, { 'rubber', 25 } } },

    -- أسلحة بيضاء
    { item = 'weapon_knuckle',    cat = 'melee', level = 0, xp = 8,  time = 6,  mats = { { 'iron', 8 }, { 'metalscrap', 4 } } },
    { item = 'weapon_bat',        cat = 'melee', level = 0, xp = 8,  time = 6,  mats = { { 'aluminum', 14 }, { 'rubber', 4 } } },
    { item = 'weapon_crowbar',    cat = 'melee', level = 1, xp = 12, time = 8,  mats = { { 'iron', 16 }, { 'steel', 8 } } },
    { item = 'weapon_hammer',     cat = 'melee', level = 1, xp = 10, time = 7,  mats = { { 'iron', 10 }, { 'plastic', 4 } } },
    { item = 'weapon_knife',      cat = 'melee', level = 2, xp = 16, time = 9,  mats = { { 'steel', 18 }, { 'plastic', 6 } } },
    { item = 'weapon_switchblade',cat = 'melee', level = 2, xp = 16, time = 9,  mats = { { 'steel', 16 }, { 'plastic', 8 } } },
    { item = 'weapon_machete',    cat = 'melee', level = 3, xp = 22, time = 12, mats = { { 'steel', 30 }, { 'rubber', 8 } } },
    { item = 'weapon_hatchet',    cat = 'melee', level = 3, xp = 22, time = 12, mats = { { 'steel', 26 }, { 'iron', 10 } } },
    { item = 'weapon_battleaxe',  cat = 'melee', level = 4, xp = 28, time = 14, mats = { { 'steel', 40 }, { 'iron', 20 } } },

    -- مسدسات
    { item = 'weapon_snspistol',     cat = 'pistol', level = 4, xp = 45, time = 22, mats = { { 'steel', 60 }, { 'iron', 40 }, { 'plastic', 30 } } },
    { item = 'weapon_pistol50',      cat = 'pistol', level = 7, xp = 75, time = 30, mats = { { 'steel', 120 }, { 'iron', 70 }, { 'aluminum', 30 } } },

    -- رشاشات خفيفة
    { item = 'weapon_microsmg',      cat = 'smg', level = 7,  xp = 80,  time = 32, mats = { { 'steel', 120 }, { 'iron', 80 }, { 'aluminum', 50 } } },
    { item = 'weapon_minismg',       cat = 'smg', level = 8,  xp = 85,  time = 33, mats = { { 'steel', 125 }, { 'iron', 85 }, { 'aluminum', 50 } } },
    { item = 'weapon_gusenberg',     cat = 'smg', level = 10, xp = 105, time = 38, mats = { { 'steel', 170 }, { 'iron', 110 }, { 'copper', 50 } } },

    -- شوزن
    { item = 'weapon_dbshotgun',       cat = 'shotgun', level = 7,  xp = 80,  time = 32, mats = { { 'steel', 120 }, { 'iron', 85 }, { 'rubber', 25 } } },

    -- رشاشات
    { item = 'weapon_compactrifle',  cat = 'rifle', level = 9,  xp = 100, time = 38, mats = { { 'steel', 170 }, { 'iron', 115 }, { 'aluminum', 65 } } },

    -- قناص (مستوى 12)
    { item = 'weapon_sniperrifle',   cat = 'sniper', level = 12, xp = 150, time = 55, mats = { { 'steel', 260 }, { 'iron', 170 }, { 'aluminum', 100 }, { 'glass', 40 } } },

    -- ذخيرة
    { item = 'pistol_ammo',  cat = 'ammo', level = 3,  xp = 12, time = 8,  mats = { { 'metalscrap', 20 }, { 'copper', 14 } } },
    { item = 'shotgun_ammo', cat = 'ammo', level = 6,  xp = 16, time = 10, mats = { { 'metalscrap', 25 }, { 'plastic', 15 }, { 'copper', 10 } } },
    { item = 'smg_ammo',     cat = 'ammo', level = 7,  xp = 18, time = 10, mats = { { 'metalscrap', 25 }, { 'copper', 18 } } },
    { item = 'rifle_ammo',   cat = 'ammo', level = 9,  xp = 22, time = 12, mats = { { 'metalscrap', 35 }, { 'copper', 25 }, { 'steel', 10 } } },
    { item = 'snp_ammo',     cat = 'ammo', level = 12, xp = 26, time = 14, mats = { { 'metalscrap', 40 }, { 'copper', 30 }, { 'steel', 20 } } },

    -- ملحقات
    { item = 'flashlight_attachment', cat = 'attach', level = 5,  xp = 30, time = 14, mats = { { 'aluminum', 30 }, { 'glass', 10 }, { 'plastic', 15 } } },
    { item = 'clip_attachment',       cat = 'attach', level = 6,  xp = 35, time = 16, mats = { { 'steel', 50 }, { 'metalscrap', 30 }, { 'rubber', 15 } } },
    { item = 'suppressor_attachment', cat = 'attach', level = 6,  xp = 40, time = 18, mats = { { 'steel', 70 }, { 'aluminum', 40 }, { 'rubber', 20 } } },
    { item = 'grip_attachment',       cat = 'attach', level = 7,  xp = 40, time = 18, mats = { { 'steel', 40 }, { 'rubber', 30 }, { 'plastic', 20 } } },
    { item = 'smallscope_attachment', cat = 'attach', level = 7,  xp = 45, time = 20, mats = { { 'glass', 30 }, { 'aluminum', 40 }, { 'steel', 30 } } },
    { item = 'medscope_attachment',   cat = 'attach', level = 8,  xp = 50, time = 22, mats = { { 'glass', 40 }, { 'aluminum', 50 }, { 'steel', 35 } } },
    { item = 'drum_attachment',       cat = 'attach', level = 9,  xp = 55, time = 24, mats = { { 'steel', 100 }, { 'metalscrap', 60 }, { 'rubber', 40 } } },
    { item = 'largescope_attachment', cat = 'attach', level = 12, xp = 70, time = 28, mats = { { 'glass', 60 }, { 'aluminum', 70 }, { 'steel', 50 } } },
}
