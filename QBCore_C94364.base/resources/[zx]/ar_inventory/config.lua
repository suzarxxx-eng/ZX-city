Config = {}

Config.MaxWeight      = 150.0   -- أقصى وزن (كغم)
Config.Slots          = 30      -- عدد خانات الحقيبة
Config.HotbarSlots    = 5       -- خانات الاستخدام السريع (مفاتيح 1-5)
Config.OpenKey        = 'F2'    -- زر فتح الحقيبة (اللاعب يقدر يغيره من إعدادات FiveM)

Config.GiveDistance   = 3.0     -- أقصى مسافة لإعطاء غرض للاعب
Config.PickupDistance = 1.8     -- مسافة التقاط الأغراض المرمية
Config.DropLifetime   = 600     -- ثواني قبل اختفاء الغرض المرمي
Config.UseCooldown    = 800     -- مدة الانتظار بين كل استخدام (ملي ثانية)

-- أغراض يستلمها اللاعب أول مرة يدخل السيرفر
Config.StartItems = {
    { 'water', 2 },
    { 'bread', 2 },
    { 'phone', 1 },
}

--[[
    كل غرض:
    label    = الاسم المعروض
    weight   = وزن الحبة بالكغم
    icon     = ايموجي (يظهر إذا ماكو صورة)
    image    = (اختياري) اسم صورة داخل html/img مثل 'water.png'
    desc     = وصف
    stack    = false إذا الغرض ما ينجمع بنفس الخانة
    usable   = true إذا ينستخدم
    consume  = false إذا ما يختفي بعد الاستخدام
    effect   = { health = رقم, armor = رقم }
    anim     = { dict = '', name = '', time = ملي ثانية }
    serverEvent = اسم حدث سيرفر ينشغل عند الاستخدام (للربط مع سكربتات ثانية)
]]
Config.Items = {
    water = {
        label = 'ماء', weight = 0.5, icon = '💧', desc = 'قنينة ماء بارد.',
        usable = true, effect = { health = 5 },
        anim = { dict = 'mp_player_intdrink', name = 'loop_bottle', time = 2500 },
    },
    bread = {
        label = 'خبز', weight = 0.3, icon = '🍞', desc = 'خبز طازج.',
        usable = true, effect = { health = 10 },
        anim = { dict = 'mp_player_inteat@burger', name = 'mp_player_int_eat_burger', time = 3000 },
    },
    burger = {
        label = 'برغر', weight = 0.4, icon = '🍔', desc = 'وجبة سريعة.',
        usable = true, effect = { health = 20 },
        anim = { dict = 'mp_player_inteat@burger', name = 'mp_player_int_eat_burger', time = 3500 },
    },
    bandage = {
        label = 'ضمادة', weight = 0.2, icon = '🩹', desc = 'تعالج الجروح البسيطة.',
        usable = true, effect = { health = 25 },
    },
    medkit = {
        label = 'حقيبة إسعاف', weight = 1.5, icon = '🧰', desc = 'علاج كامل للإصابات.',
        usable = true, effect = { health = 75 },
    },
    armor = {
        label = 'درع واقي', weight = 3.0, icon = '🛡️', desc = 'حماية ضد الرصاص.',
        usable = true, effect = { armor = 100 },
    },
    phone = {
        label = 'هاتف', weight = 0.2, icon = '📱', desc = 'هاتفك الشخصي.',
        stack = false,
    },
    radio = {
        label = 'جهاز لاسلكي', weight = 0.5, icon = '📻', desc = 'للتواصل مع الفريق.',
        stack = false,
    },
    lockpick = {
        label = 'أداة فتح الأقفال', weight = 0.3, icon = '🗝️', desc = 'تفتح الأقفال البسيطة.',
    },
    repairkit = {
        label = 'عدة تصليح', weight = 2.5, icon = '🔧', desc = 'لتصليح المركبات.',
    },
    id_card = {
        label = 'الهوية الشخصية', weight = 0.05, icon = '🪪', desc = 'هوية رسمية.',
        stack = false,
    },
}
