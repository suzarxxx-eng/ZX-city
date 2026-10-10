Config = {}

Config.Jobs = { police = true, army = true }   -- منو يكدر يفتح الـ MDT
Config.Key = 'K'                               -- يتغير من إعدادات اللعبة > Key Bindings > FiveM
Config.Command = 'mdt'
Config.NeedDuty = false                        -- true = لازم يكون بالدوام حتى يفتحه
Config.Tablet = true                           -- يمسك تابلت بإيده
Config.Debug = true                            -- يطبع كل طلب بكونسول السيرفر (للفحص، طفيه بعدين)

Config.DeleteGrade = 7      -- من نقيب وفوك يكدر يحذف تقارير / أوامر قبض / تعميمات
Config.JailDistance = 6.0   -- السجن من الـ MDT يشتغل بس إذا المتهم يمك (متر)
Config.NearbyDistance = 10.0 -- "الأشخاص القريبين" بصفحة القضايا (متر)
Config.MaxJail = 300        -- أعلى مدة سجن يكدر يكتبها الضابط (شهر)
Config.MaxFine = 250000     -- أعلى غرامة
Config.FineAccount = 'bank' -- الغرامة تنسحب من البنك

Config.Statuses = {         -- حالات الوحدات
    { id = 'available', label = 'متاح',          color = '#3ddc97' },
    { id = 'patrol',    label = 'بدورية',        color = '#2f8cff' },
    { id = 'busy',      label = 'مشغول',         color = '#ffa94d' },
    { id = 'scene',     label = 'بموقع حادث',    color = '#ff4d6d' },
    { id = 'break',     label = 'استراحة',       color = '#8fa9cf' },
}

Config.Licenses = {         -- الرخص اللي تبين وتتغير من الملف الشخصي
    { id = 'driver',   label = 'رخصة سياقة' },
    { id = 'weapon',   label = 'رخصة سلاح' },
    { id = 'business', label = 'رخصة تجارية' },
}

Config.Tags = { 'خطر', 'مسلح', 'مطلوب', 'عصابة', 'مراقبة', 'متعاون' }

Config.ReportTypes = { 'حادث مروري', 'سرقة', 'اعتداء', 'إطلاق نار', 'مخدرات', 'مطاردة', 'تحقيق', 'أخرى' }

-- قانون العقوبات: fine = غرامة بالدولار، jail = أشهر سجن
Config.Penal = {
    {
        category = 'مخالفات مرورية', color = '#3bc9db',
        items = {
            { id = 't1', label = 'تجاوز السرعة المحددة',      fine = 500,   jail = 0 },
            { id = 't2', label = 'قطع الإشارة الحمراء',       fine = 750,   jail = 0 },
            { id = 't3', label = 'قيادة بدون رخصة',           fine = 1500,  jail = 0 },
            { id = 't4', label = 'قيادة متهورة',               fine = 2000,  jail = 5 },
            { id = 't5', label = 'وقوف مخالف',                 fine = 250,   jail = 0 },
            { id = 't6', label = 'عدم الامتثال لأمر التوقف',   fine = 3000,  jail = 10 },
        },
    },
    {
        category = 'جنح', color = '#ffa94d',
        items = {
            { id = 'm1', label = 'إزعاج عام',                  fine = 500,   jail = 0 },
            { id = 'm2', label = 'إهانة موظف حكومي',           fine = 1500,  jail = 5 },
            { id = 'm3', label = 'رفض إبراز الهوية',           fine = 1000,  jail = 0 },
            { id = 'm4', label = 'تخريب ممتلكات',              fine = 2500,  jail = 10 },
            { id = 'm5', label = 'سرقة بسيطة',                 fine = 3000,  jail = 15 },
            { id = 'm6', label = 'حيازة مواد ممنوعة (قليلة)',  fine = 4000,  jail = 15 },
            { id = 'm7', label = 'مقاومة الاعتقال',            fine = 5000,  jail = 20 },
        },
    },
    {
        category = 'جنايات', color = '#ff4d6d',
        items = {
            { id = 'f1', label = 'سرقة سيارة',                 fine = 7500,  jail = 25 },
            { id = 'f2', label = 'حمل سلاح بدون رخصة',         fine = 10000, jail = 30 },
            { id = 'f3', label = 'اعتداء بسلاح',               fine = 15000, jail = 40 },
            { id = 'f4', label = 'سطو مسلح على محل',           fine = 20000, jail = 50 },
            { id = 'f5', label = 'سطو على بنك',                fine = 40000, jail = 80 },
            { id = 'f6', label = 'تجارة مخدرات',               fine = 25000, jail = 60 },
            { id = 'f7', label = 'اختطاف',                     fine = 30000, jail = 70 },
            { id = 'f8', label = 'الشروع بالقتل',              fine = 35000, jail = 90 },
            { id = 'f9', label = 'قتل عمد',                    fine = 50000, jail = 120 },
            { id = 'f10', label = 'الاعتداء على رجل أمن',      fine = 30000, jail = 75 },
        },
    },
}
