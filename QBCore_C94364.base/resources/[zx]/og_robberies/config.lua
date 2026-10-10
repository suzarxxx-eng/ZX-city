Config = {}

Config.Framework = 'auto'          -- 'auto' | 'qb' | 'esx'
Config.Debug = false               -- true: draws all spots & enables /rob_here for admins to print coords

-- true: a spot stays disabled (no marker, no robbery) until an admin places it with /rob_setspot <id>
Config.OnlyConfiguredSpots = true

Config.InteractKey = 38            -- E
Config.CancelKey = 73              -- X
Config.MarkerDistance = 8.0        -- marker only appears this close (no map blips at all)
Config.InteractDistance = 2.2      -- distance to press [E]
Config.ServerMaxDistance = 3.5     -- server re-checks the player is this close
Config.AntiSpamMs = 2000           -- minimum time between requests per player
Config.MarkerColor = { r = 0, g = 150, b = 255, a = 170 }

-- Lockpick challenge: set `pins` pins by pressing SPACE when the needle is inside the blue zone.
-- Every miss costs one life; 0 lives = fail and the lockpick is lost. Per-location `game = {...}` overrides these.
Config.Minigame = {
    pins = 3,
    lives = 3,
    zone = 44,          -- size of the blue zone in degrees (smaller = harder)
    speed = 200,        -- needle speed in degrees/second (the needle speeds up a bit after each pin)
    minSeconds = 3,     -- server rejects a "success" faster than this (basic anti-cheat)
    maxSeconds = 120,   -- the spot is freed if the client never reports back
}

-- Chance (on success) to find a gun blueprint from og_crafting. Never given on failure.
Config.Blueprint = {
    chance = 0.04,      -- 4%
    category = 'pistol',
}

Config.Police = {
    jobs = { police = true, sheriff = true, bcso = true },   -- jobs counted as law enforcement
    dispatchResource = 'ar_dispatch',                         -- server uses exports[...]:Alert if started
}

-- Every spot: coords are approximate -> stand on the exact spot and use /rob_here (Config.Debug = true) to refine them.
-- time (unused, kept for compatibility), reward {min,max} cash, cooldown (min, global per spot), minPolice, item (required tool), itemBreak (chance it breaks on SUCCESS; it is always lost on a failed challenge), alertChance (0-1)
-- Optional: game = { pins=4, lives=2, zone=36, speed=240 } to make a spot harder
Config.Locations = {
    { id = 'unicorn',    label = 'خزنة المكتب الخلفي', coords = vec3(95.6, -1293.5, 29.3),   time = 40, reward = { 6000, 11000 },  cooldown = 60, minPolice = 0, item = 'lockpick', itemBreak = 0.0, alertChance = 0.6 },
    { id = 'tequila',    label = 'صندوق المكتب',       coords = vec3(-565.2, 285.0, 82.2),   time = 45, reward = { 7000, 12000 },  cooldown = 60, minPolice = 0, item = 'lockpick', itemBreak = 0.0, alertChance = 0.6 },
    { id = 'yellowjack', label = 'خزنة الحانة',        coords = vec3(1990.9, 3052.5, 47.2),  time = 35, reward = { 4000, 8000 },   cooldown = 45, minPolice = 0, item = 'lockpick', itemBreak = 0.0, alertChance = 0.4 },
    { id = 'docks',      label = 'حاوية الميناء',      coords = vec3(1197.5, -3253.5, 7.1),  game = { pins = 4, zone = 38, speed = 230 }, time = 60, reward = { 12000, 20000 }, cooldown = 90, minPolice = 1, item = 'lockpick', itemBreak = 0.0, alertChance = 0.8 },
    { id = 'barn',       label = 'مخزن المزرعة',       coords = vec3(2433.0, 4969.0, 46.8),  time = 30, reward = { 3000, 6000 },   cooldown = 40, minPolice = 0, item = nil,        itemBreak = 0,   alertChance = 0.2 },
    { id = 'sawmill',    label = 'مكتب المنشرة',       coords = vec3(-535.0, 5412.0, 70.4),  time = 40, reward = { 5000, 9000 },   cooldown = 50, minPolice = 0, item = 'lockpick', itemBreak = 0.0, alertChance = 0.4 },
    { id = 'warehouse',  label = 'مستودع سايبرس',      coords = vec3(962.0, -2119.0, 30.5),  game = { pins = 4, zone = 38, speed = 230 }, time = 55, reward = { 10000, 17000 }, cooldown = 80, minPolice = 1, item = 'lockpick', itemBreak = 0.0, alertChance = 0.8 },
    { id = 'canals',     label = 'قبو القنوات',        coords = vec3(-1172.0, -1572.5, 4.7), time = 45, reward = { 6000, 10000 },  cooldown = 60, minPolice = 0, item = 'lockpick', itemBreak = 0.0, alertChance = 0.5 },
}

-- Optional bonus items (rolled once per robbery); skipped if the item does not exist
Config.BonusItems = {
    { item = 'goldbar',      chance = 0.10, amount = { 1, 2 } },
    { item = 'rolex',        chance = 0.15, amount = { 1, 2 } },
    { item = 'diamond_ring', chance = 0.12, amount = { 1, 1 } },
}

Config.Text = {
    prompt = 'اضغط للسرقة',
    cancel = 'ألغيت العملية',
    cooldown = 'المكان فاضي، رجع بعدين',
    busy = 'شخص ثاني يسرق هنا',
    police = 'الوضع هادئ جداً، ما يصير الحين',
    noitem = 'تحتاج أداة فتح',
    tooFast = 'القفل ما انفتح، حاول مرة ثانية',
    tooFar = 'ابتعدت عن المكان',
    done = 'خلصت السرقة! حصلت على $%s',
    started = 'بديت العملية... لا تتحرك',
    spam = 'اهدأ شوية',
    progress = 'افتح القفل',
    failed = 'فشلت وانكسرت الأداة',
    blueprint = 'لكيت مخطوطة مسدس!',
}
