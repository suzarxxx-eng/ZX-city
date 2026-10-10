Config = {}

-- الأرينا ساحة معلقة بالسما فوك البحر. تنبني بس عند اللي يدخلها (محد بالمدينة يشوفها، وما إلها علامة بالخريطة)
-- كل سلاح إله عالم (bucket) خاص وساحة بحجم يناسبه
Config.Sky = vector3(-5600.0, -2600.0, 1150.0)

Config.Arenas = {
    pistol = {
        label = 'مسدس', en = 'PISTOL', weapon = `WEAPON_PISTOL50`, bucket = 7101, color = '#3ddc97',
        size = 60.0, cover = 0.22, seed = 11, place = 'ساحة صغيرة',
    },
    ak = {
        label = 'AK', en = 'ASSAULT', weapon = `WEAPON_ASSAULTRIFLE`, bucket = 7102, color = '#ff7a3d',
        size = 90.0, cover = 0.20, seed = 22, place = 'ساحة متوسطة',
    },
    sniper = {
        label = 'سنايبر', en = 'SNIPER', weapon = `WEAPON_SNIPERRIFLE`, bucket = 7103, color = '#38c8ff',
        size = 140.0, cover = 0.12, seed = 33, towers = true, place = 'ساحة كبيرة',
    },
    shotgun = {
        label = 'شوزن', en = 'SHOTGUN', weapon = `WEAPON_PUMPSHOTGUN`, bucket = 7104, color = '#ff4d6d',
        size = 44.0, cover = 0.28, seed = 44, place = 'ساحة ضيقة',
    },
}
Config.Order = { 'pistol', 'ak', 'sniper', 'shotgun' }

-- الموديلات (السكربت ياخذ أول واحد موجود باللعبة، ويقيس حجمه وحده)
Config.FloorModels = { `stt_prop_stunt_bblock_huge_01`, `stt_prop_stunt_bblock_lrg1`, `prop_container_05a` }
Config.WallModels = { `prop_container_05a`, `prop_container_01a` }
Config.CoverModels = {
    `prop_container_05a`, `prop_mb_sandblock_01`, `prop_conc_blocks01a`, `prop_barier_conc_05c`,
    `prop_mp_conc_barrier_01`, `prop_byard_sleeper01`, `prop_cratepile_07a`, `prop_boxpile_07d`,
}

-- ===================== تيد ام (غرف خاصة) =====================
Config.Tdm = {
    Sky = vector3(-5600.0, -4600.0, 1180.0), -- ماب التيد ام (بعيد عن الأرينا)
    Width = 46.0, Length = 104.0,            -- عرض وطول الساحة
    Cover = 0.26, Seed = 77,                 -- كثافة السواتر (مرايا: نفس الشي للفريقين)
    BaseDepth = 12.0,                        -- منطقة نزول كل فريق (بدون سواتر)
    MaxPlayers = 8,
    BucketBase = 7300,
    Targets = { 20, 30, 50 },                -- عدد القتلات للفوز
    Times = { 5, 10, 15 },                   -- دقايق
    EndScreen = 9,                           -- ثواني شاشة النتيجة
    Weapons = {
        pistol  = { label = 'مسدس',   hash = `WEAPON_PISTOL50` },
        ak      = { label = 'AK',     hash = `WEAPON_ASSAULTRIFLE` },
        sniper  = { label = 'سنايبر', hash = `WEAPON_SNIPERRIFLE` },
        shotgun = { label = 'شوزن',   hash = `WEAPON_PUMPSHOTGUN` },
    },
}

Config.Armor = 100
Config.RespawnTime = 3000     -- بعد الموت يرجع بعد هالوقت (ms)
Config.SpawnProtect = 2500    -- حماية بعد النزول (ms)
Config.LeaveCommand = 'leavearena'
