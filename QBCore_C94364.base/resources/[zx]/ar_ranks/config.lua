Config = {}

-- الوظايف اللي تشتغل عليها اللوحة (الرتب نفسها مكتوبة بـ qb-core/shared/jobs.lua)
Config.Jobs = { police = true, army = true }

Config.Command = 'ranks'   -- /ranks
Config.Key = 'F9'          -- اختصار يفتح اللوحة (يتغير من إعدادات اللعبة > Key Bindings > FiveM)

-- من هاي الرتبة وفوك يكدر يرفّع وينزّل اللي تحته (11 = عميد)
Config.ManageFrom = 11

-- التعيين والفصل بس لصاحب isboss (لواء / لواء ركن)
Config.BossOnlyHireFire = true

-- يوصل إشعار لكل منتسبي الوظيفة لمن أحد يترفع
Config.AnnouncePromotions = true

-- شارات الرتب حسب رقم الرتبة
-- chev = عدد الأشرطة، stars = نجوم، eagle = نسر، swords = سيفين، red = شارة الركن الحمراء
Config.Insignia = {
    [0]  = {},
    [1]  = { chev = 1 },
    [2]  = { chev = 2 },
    [3]  = { chev = 3 },
    [4]  = { chev = 3, bar = true },
    [5]  = { stars = 1 },
    [6]  = { stars = 2 },
    [7]  = { stars = 3 },
    [8]  = { eagle = true },
    [9]  = { eagle = true, stars = 1 },
    [10] = { eagle = true, stars = 2 },
    [11] = { eagle = true, stars = 3 },
    [12] = { swords = true, eagle = true, stars = 1 },
    [13] = { swords = true, eagle = true, stars = 1, red = true },
}

-- أقسام الرتب باللوحة
Config.Groups = {
    { from = 0,  to = 4,  label = 'المراتب' },
    { from = 5,  to = 10, label = 'الضباط' },
    { from = 11, to = 99, label = 'القادة' },
}
