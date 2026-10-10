--[[
    تصميم المركز (كل الإحداثيات نسبية لنقطة البوابة اللي يوكف عليها الأدمن)
    x = يمين/يسار البوابة      y = لداخل المركز (لكدام)      h = اتجاه الغرض
    مساحة المركز: 32 متر عرض × 28 متر عمق

                    [حمام]          [حاوية]
      [مكتب 1]     [ساحة الاجتماع: خيمة + مكاتب]
      [مكتب 2]  [علم]                 [سيارات]
      [مولد]                          [سيارات]
      ====== حواجز ======[ بوابة ]====== حواجز ======
]]

Layout = {}

local function add(model, x, y, h, opts)
    local e = { model = model, x = x, y = y, h = h or 0.0 }
    if opts then for k, v in pairs(opts) do e[k] = v end end
    Layout[#Layout + 1] = e
end

local W, D = 16.0, 28.0 -- نص العرض، العمق

---------------------------------------------------------------- السور
-- الواجهة: حواجز شرطة على جانبي البوابة
for x = 4.0, W, 2.2 do
    add('prop_mp_barrier_02b', x, 0.0, 0.0)
    add('prop_mp_barrier_02b', -x, 0.0, 0.0)
end
-- الجوانب والخلف: سياج
for y = 1.8, D, 3.4 do
    add('prop_const_fence02a', W, y, 90.0)
    add('prop_const_fence02a', -W, y, 90.0)
end
for x = -W + 1.7, W - 1.0, 3.4 do
    add('prop_const_fence02a', x, D, 0.0)
end

---------------------------------------------------------------- البوابة
add('prop_sec_barrier_ld_01a', -2.6, 0.0, 0.0)      -- ذراع البوابة
add('prop_roadcone02a', -3.4, -1.5, 0.0)
add('prop_roadcone02a', 3.4, -1.5, 0.0)
add('prop_roadcone02a', -3.4, -3.5, 0.0)
add('prop_roadcone02a', 3.4, -3.5, 0.0)
add('prop_mp_arrow_barrier_01', 0.0, -5.5, 180.0)   -- لوحة تنبيه قبل البوابة

---------------------------------------------------------------- المكاتب (كرفانات)
add('prop_portacabin01', -10.5, 21.0, 90.0)
add('prop_portacabin01', -10.5, 12.5, 90.0)
add('prop_generator_03b', -13.5, 6.5, 0.0)
add('prop_barrel_02a', -14.6, 4.6, 0.0)
add('prop_barrel_02a', -14.6, 3.6, 0.0)

---------------------------------------------------------------- ساحة الاجتماع (خيمة + مكاتب)
add('prop_gazebo_02', 3.0, 20.0, 0.0)
add('prop_office_desk_01', 1.2, 19.0, 180.0)
add('prop_office_desk_01', 4.8, 19.0, 180.0)
add('prop_off_chair_04', 1.2, 17.9, 180.0)
add('prop_off_chair_04', 4.8, 17.9, 180.0)
add('prop_laptop_01a', 1.2, 19.2, 0.0, { z = 0.78 })
add('prop_laptop_01a', 4.8, 19.2, 0.0, { z = 0.78 })
add('prop_watercooler', 7.0, 22.0, 180.0)
add('prop_bench_01a', 3.0, 14.5, 0.0)

---------------------------------------------------------------- العلم والإنارة
add('prop_flagpole_1a', -5.0, 3.5, 0.0)
add('prop_worklight_03b', -W + 1.2, 1.2, 225.0)
add('prop_worklight_03b', W - 1.2, 1.2, 135.0)
add('prop_worklight_03b', -W + 1.2, D - 1.2, 315.0)
add('prop_worklight_03b', W - 1.2, D - 1.2, 45.0)

---------------------------------------------------------------- الخلف
add('prop_portaloo_01a', 13.5, 25.5, 180.0)
add('prop_container_01a', -1.0, 25.5, 90.0)

---------------------------------------------------------------- مواقف السيارات (يمين)
ParkedCars = {
    { model = 'police',  x = 11.0, y = 5.0,  h = 270.0 },
    { model = 'police2', x = 11.0, y = 9.0,  h = 270.0 },
    { model = 'police3', x = 11.0, y = 13.0, h = 270.0 },
}
for _, c in ipairs(ParkedCars) do
    add('prop_roadcone01a', c.x + 3.4, c.y, 0.0) -- كون ورا كل موقف
end
