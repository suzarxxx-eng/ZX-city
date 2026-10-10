Config = {}

Config.Jobs = { police = true, army = true }  -- منو يستلم البلاغات (لازم يكون بالدوام)
Config.GpsKey = 'G'          -- يحدد GPS على آخر بلاغ ويسجلك مستجيب
Config.ShowTime = 9000       -- كم يبقى الإشعار على الشاشة (ms)
Config.BlipTime = 150        -- كم ثانية تبقى النقطة على الخريطة
Config.KeepAlerts = 60       -- كم بلاغ ينحفظ بسجل البلاغات (الـ MDT)
Config.Sound = true

-- أنواع البلاغات
-- code = الكود اللاسلكي، sprite/color = شكل ولون النقطة على الخريطة
Config.Types = {
    shooting   = { code = '10-71', title = 'إطلاق نار',          color = '#ff4d6d', blip = { sprite = 110, color = 1 },  priority = 2 },
    carjack    = { code = '10-60', title = 'سلب سيارة بالقوة',    color = '#ffa94d', blip = { sprite = 229, color = 17 }, priority = 2 },
    cartheft   = { code = '10-60', title = 'سرقة سيارة',          color = '#ffa94d', blip = { sprite = 229, color = 17 }, priority = 1 },
    store      = { code = '10-90', title = 'سرقة متجر',           color = '#ff8f3d', blip = { sprite = 52,  color = 47 }, priority = 2 },
    jewelry    = { code = '10-90', title = 'سرقة مجوهرات',        color = '#ff8f3d', blip = { sprite = 617, color = 47 }, priority = 2 },
    house      = { code = '10-31', title = 'سطو على بيت',         color = '#ffa94d', blip = { sprite = 40,  color = 17 }, priority = 1 },
    bank       = { code = '10-90', title = 'سرقة بنك',            color = '#ff2e57', blip = { sprite = 108, color = 1 },  priority = 3 },
    truck      = { code = '10-90', title = 'سرقة شاحنة أموال',    color = '#ff2e57', blip = { sprite = 67,  color = 1 },  priority = 3 },
    prison     = { code = '10-98', title = 'هروب من السجن',       color = '#ff2e57', blip = { sprite = 188, color = 1 },  priority = 3 },
    suspicious = { code = '10-37', title = 'حركة مشبوهة',         color = '#f5c451', blip = { sprite = 66,  color = 5 },  priority = 1 },
    drugs      = { code = '10-37', title = 'بيع مخدرات',          color = '#f5c451', blip = { sprite = 51,  color = 5 },  priority = 1 },
    officer    = { code = '10-99', title = 'ضابط بخطر',           color = '#2f8cff', blip = { sprite = 526, color = 3 },  priority = 3 },
    distress   = { code = '10-52', title = 'نداء استغاثة',        color = '#3bc9db', blip = { sprite = 280, color = 3 },  priority = 2 },
    radar      = { code = '10-28', title = 'مركبة مطلوبة بالرادار', color = '#cc5de8', blip = { sprite = 225, color = 27 }, priority = 2 },
    call       = { code = '10-11', title = 'اتصال طوارئ',         color = '#3bc9db', blip = { sprite = 459, color = 3 },  priority = 1 },
    general    = { code = '10-00', title = 'بلاغ',                color = '#6bb3ff', blip = { sprite = 161, color = 3 },  priority = 1 },
}

-- الكشف التلقائي
Config.Auto = {
    shooting = { enabled = true, cooldown = 25, chance = 100 },  -- chance = نسبة إرسال البلاغ %
    carjack  = { enabled = true, cooldown = 30, chance = 100 },
    aiming   = { enabled = true, cooldown = 60, chance = 60, seconds = 3 }, -- يوجه سلاح على شخص = حركة مشبوهة
}

-- أسلحة ما تسوي بلاغ إطلاق نار
Config.IgnoreWeapons = {
    `WEAPON_STUNGUN`, `WEAPON_FLARE`, `WEAPON_FLAREGUN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_PETROLCAN`,
    `WEAPON_SNOWBALL`, `WEAPON_BALL`, `WEAPON_HAZARDCAN`, `WEAPON_STUNGUN_MP`,
}

-- أماكن ما ينطلع منها بلاغ إطلاق نار (ساحات رماية...)
Config.NoShootZones = {
    { coords = vector3(13.5, -1097.5, 29.8), radius = 25.0 },   -- Ammu-Nation ساحة الرماية
    { coords = vector3(821.6, -2163.5, 29.6), radius = 25.0 },  -- Ammu-Nation سايبرس
}
