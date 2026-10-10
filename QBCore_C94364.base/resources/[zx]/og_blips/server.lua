local QBCore = exports['qb-core']:GetCoreObject()
local FILE = 'blips.json'
local List = {}

do
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then List = t end
    end
end

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(List), -1)
end

RegisterNetEvent('og_blips:server:request', function()
    TriggerClientEvent('og_blips:client:list', source, List)
end)

-- /blipadd <sprite> <color> <الاسم>  : يضيف أيقونة بمكانك الحالي (للأدمن)
-- مثال: /blipadd 52 5 متجر      (sprite 52 = متجر، color 5 = أصفر)
QBCore.Commands.Add('blipadd', 'إضافة أيقونة بمكانك: /blipadd رقم_الشكل رقم_اللون الاسم', {
    { name = 'الشكل', help = 'رقم الأيقونة (مثلاً 52 متجر، 60 شرطة، 361 وقود)' },
    { name = 'اللون', help = 'رقم اللون (0 أبيض، 1 أحمر، 2 أخضر، 3 أزرق، 5 أصفر)' },
    { name = 'الاسم', help = 'اسم الأيقونة' },
}, false, function(source, args)
    local sprite, color = tonumber(args[1]), tonumber(args[2])
    if not sprite or not color or #args < 3 then
        return TriggerClientEvent('QBCore:Notify', source, 'الصيغة: /blipadd 52 5 متجر', 'error')
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return TriggerClientEvent('QBCore:Notify', source, 'ما كدرت أقرا مكانك (OneSync)', 'error') end
    local c = GetEntityCoords(ped)
    local label = table.concat(args, ' ', 3)
    List[#List + 1] = { x = c.x, y = c.y, z = c.z, sprite = sprite, color = color, label = label }
    save()
    TriggerClientEvent('og_blips:client:list', -1, List)
    TriggerClientEvent('QBCore:Notify', source, ('تمت إضافة أيقونة: %s'):format(label), 'success')
end, 'admin')

-- /blipundo: يحذف آخر أيقونة أضفتها
QBCore.Commands.Add('blipundo', 'حذف آخر أيقونة أضفتها', {}, false, function(source)
    if #List == 0 then return TriggerClientEvent('QBCore:Notify', source, 'ماكو أيقونات مضافة', 'error') end
    local removed = table.remove(List)
    save()
    TriggerClientEvent('og_blips:client:list', -1, List)
    TriggerClientEvent('QBCore:Notify', source, ('انحذفت: %s'):format(removed.label), 'success')
end, 'admin')
