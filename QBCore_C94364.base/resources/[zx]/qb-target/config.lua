Config = {}

-- زر العين (اضغط مطولاً). LMENU = Left Alt
-- كل لاعب يكدر يغيره من إعدادات FiveM > Key Bindings
Config.OpenKey = 'LMENU'

-- أقصى مدى للتصويب من الكاميرا (بالأمتار)
Config.MaxDistance = 10.0

-- من أي مسافة تطلع خيارات السيارة (الأبواب، الصندوق، الكبوت) بالأمتار
Config.VehicleDistance = 3.5

-- المسافة الافتراضية للخيارات إذا السكربت ما حدد مسافة
Config.DefaultDistance = 2.5

-- تعمل العين وأنت داخل السيارة؟
Config.EnableInVehicle = true

-- إظهار حدود المناطق (للتجربة فقط)
Config.Debug = false

-- خيارات السيارة المدمجة (الأبواب، الشنطة، البونيت، حالة المحرك)
Config.VehicleOptions = true

-- منطقة تسجيل الدخول العسكري
Config.LoginZone = {
    enabled = true,
    coords  = vector3(264.27, -878.76, 29.0),
    length  = 2.5,
    width   = 2.5,
    heading = 325,
    minZ    = 24.0,
    maxZ    = 33.0,
    label   = 'التسجيل',
    job     = 'police', -- الوظيفة اللي ياخذها اللاعب عند التسجيل
    grade   = 4,        -- الرتبة
}

-- خيار "تفتيش الشخص": يفتح حقيبة اللاعب الثاني
Config.Search = {
    enabled     = true,
    allowedJobs = { 'police', 'army' },
    maxDistance = 3.0, -- أقصى مسافة بين المفتّش والهدف بالأمتار
}
