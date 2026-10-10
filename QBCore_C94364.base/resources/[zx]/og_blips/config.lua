Config = {}

-- الأيقونات اللي ما تنشال (رقم نوع الأيقونة): 8 = علامة الـ GPS (waypoint)
Config.KeepSprites = { [8] = true }

-- كل أيقونات الخريطة تنشال دائماً، وبس اللي تكتبه هنا يبقى. أضف أيقونة بهذا الشكل:
-- { coords = vector3(x, y, z), sprite = 52, color = 5, scale = 0.8, label = 'اسم الأيقونة' },
Config.Blips = {
    -- وزارة الداخلية (شعار الشرطة = sprite 60، أزرق)
    { coords = vector3(428.23, -984.28, 29.76), sprite = 60, color = 3, scale = 1.0, label = 'وزارة الداخلية' },
}
