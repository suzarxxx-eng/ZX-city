Config = {}

Config.Jobs = { police = true, army = true }

-- المكاتب (تكدر تضيف مكتب من اللعبة: وكف يم المكتب واكتب /opsdesk)
-- هذا مكتب الاستقبال بمركز Mission Row
Config.Desks = {
    { coords = vector3(440.08, -974.92, 30.69), heading = 0.0, length = 2.2, width = 1.4 },
}

Config.Distance = 2.0

-- أقل رتبة تكدر تستلم (0 = الكل)
Config.ChiefMinGrade = 0
Config.DeputyMinGrade = 0

Config.Labels = {
    chief = 'مسؤول عمليات',
    deputy = 'نائب عمليات',
}
