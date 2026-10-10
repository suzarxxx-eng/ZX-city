Config = {}

--[[
    نظام الوظائف - طريقة إضافة وظيفة جديدة:
    1) انسخ أي ملف من مجلد jobs/ وغير الاسم والإعدادات (لازم Config.Jobs['اسم_جديد'] = { ... })
    2) أضف الأغراض الجديدة لـ qb-core/shared/items.lua
    3) اكتب: refresh ثم ensure og_jobs

    أنواع المراحل (stages):
      gather  = جمع من نقاط (خشب، معادن، سمك...)   points = { {coords, radius} }
      process = معالجة بمحطة (نشر، صهر، تنظيف...)   station = coords
      sell    = بيع الأغراض                          station = coords
    وظيفة التكسي (type = 'taxi') لها نظام مشاوير خاص.

    حقول اختيارية بكل وظيفة تظهر بمركز التوظيف: emoji = '🌲' (الأيقونة)، desc = 'وصف قصير'
    (المراحل والأدوات وأعلى سعر بيع تنقرأ تلقائياً من stages/tools/prices).

    أيقونات الخريطة (كلها بالعربي ومن خلال og_blips):
      boss.blip = { sprite, color, scale }  أيقونة «تسجيل دخول <الوظيفة>»: تظهر للموظف بهذي الوظيفة فقط (حتى لو ما سجل دخول)
      نقطة البيع وأماكن الشغل: تظهر بعد تسجيل الدخول للدوام فقط

    نقطة البيع الخاصة بالوظيفة (موظف يشتري البضاعة + أيقونة): sell = { coords = vector4(x, y, الأرض, اتجاه), model, scenario, label, blip }
      z = مستوى الأرض (ينلقى تلقائياً). ما فيها نقطة بيع؟ البيع يصير عند باب الشركة مثل قبل.
      لتغيير المكان باللعبة: قف بالمكان الجديد واكتب /jobsell <الوظيفة> (يتخزن بـ sells.json ويغطي ملف الوظيفة)
]]

-- المستويات: عدد الخبرة (XP) اللازم لكل مستوى
Config.Levels = { 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200 }

-- كل مستوى فوق الأول يزيد دخلك بهاي النسبة (0.06 = 6%)
Config.PayBonusPerLevel = 0.06

-- أقل نسبة من وقت العملية لازم تمر قبل ما السيرفر يقبل إنهاءها (ضد الغش)
Config.MinTimeRatio = 0.8

-- الدفع كاش (cash) أو بنك (bank)
Config.PayAccount = 'cash'

-- مركز التوظيف: التقديم والاستقالة يصيرون من هنا فقط (واجهة: الوظائف / وظيفتي / المتصدرين + GPS لكل وظيفة)
-- باب الشركة للدوام فقط (تسجيل دخول وخروج). لنقل المركز: قف بالمكان الجديد واكتب /jobcenter (أدمن)
-- الأيقونة علامة استفهام صفراء (sprite 66 = علامة الاستفهام، color 5 = أصفر)
Config.Center = {
    model = 'a_m_y_business_03',
    coords = vector4(207.40, -926.20, 30.69, 160.0), -- ساحة ليجن (وسط المدينة)
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip = { sprite = 66, color = 5, scale = 1.0, label = 'مركز التوظيف' },
}

-- صور الأغراض بقائمة البيع. الترتيب: صورة الغرض نفسه بمخزن qb-inventory (لمن تضيف iron_ore.png مثلاً)، ثم هذي الصور الجاهزة، ثم رسم من html/img
Config.ItemImages = {
    iron_ore = 'iron.png', copper_ore = 'copper.png', gold_ore = 'goldbar.png',
    iron_bar = 'steel.png', copper_bar = 'copper.png', gold_bar = 'goldbar.png',
    fish_catch = 'fish.png', fish_fillet = 'fish.png',
    crude_oil = 'jerry_can.png', fuel_barrel = 'jerry_can.png',
}

Config.Jobs = {}
