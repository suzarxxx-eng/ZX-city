Config = {}

-- الموظف (يتفتح بالعين: اضغط ALT مطولاً وصوّب عليه)
Config.Ped = {
    model    = 'a_m_y_business_01',
    coords   = vector4(1852.92, 2581.55, 45.67, 291.8),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- نقاط ظهور المركبات (تنخلق بأول نقطة فاضية). محسوبة قدام الموظف بـ 5 متر، عدّلها إذا المكان مو مناسب
Config.SpawnPoints = {
    vector4(1857.56, 2583.42, 45.67, 291.8),
    vector4(1858.87, 2580.17, 45.67, 291.8),
    vector4(1856.26, 2586.67, 45.67, 291.8),
}

-- الدفع: كاش أولاً وإذا ما كفى من البنك
Config.Vehicles = {
    { label = 'سيارة - Asea',       model = 'asea',   price = 400, icon = 'fas fa-car' },
    { label = 'سيارة - Blista',     model = 'blista', price = 300, icon = 'fas fa-car-side' },
    { label = 'دراجة هوائية - BMX', model = 'bmx',    price = 50,  icon = 'fas fa-bicycle' },
    { label = 'دراجة نارية - Faggio', model = 'faggio', price = 150, icon = 'fas fa-motorcycle' },
}
