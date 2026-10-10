local QBCore = exports['qb-core']:GetCoreObject()
local Alerts, nextId = {}, 0
local Cooldowns = {}  -- [src..type] = وقت

local function isCop(pd)
    return pd and Config.Jobs[pd.job.name] and pd.job.onduty
end

local function officerName(pd)
    local cs = pd.metadata.callsign
    if cs == 'NO CALLSIGN' then cs = nil end
    local n = (pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or '')
    return (cs and ('[' .. cs .. '] ') or '') .. (pd.job.grade.name or '') .. ' ' .. n
end

local function broadcast(event, payload)
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if isCop(v.PlayerData) then TriggerClientEvent(event, v.PlayerData.source, payload) end
    end
end

-- البلاغ الرئيسي: كل البلاغات تمر من هنا
-- data = { type, coords, message, details = { {label, value} }, gender, vehicle = {model, plate, color} }
local function Alert(data)
    local t = Config.Types[data.type] and data.type or 'general'
    local def = Config.Types[t]
    local c = data.coords
    if not c then return end
    nextId = nextId + 1
    local a = {
        id = nextId, type = t, code = def.code, title = data.title or def.title, color = def.color, priority = def.priority,
        message = data.message, details = data.details, vehicle = data.vehicle, gender = data.gender,
        coords = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }, time = os.time(), responders = {},
    }
    table.insert(Alerts, 1, a)
    while #Alerts > Config.KeepAlerts do table.remove(Alerts) end
    broadcast('ar_dispatch:client:alert', a)
    return a.id
end
exports('Alert', Alert)
exports('GetAlerts', function() return Alerts end)

-- من أي سكربت: TriggerEvent('ar_dispatch:server:alert', {...}) أو من الكلاينت
local function sourceInfo(src)
    local P = QBCore.Functions.GetPlayer(src)
    local gender
    if P then gender = (P.PlayerData.charinfo.gender == 1) and 'أنثى' or 'ذكر' end
    return GetEntityCoords(GetPlayerPed(src)), gender, P
end

-- الكشف التلقائي من الكلاينت (إطلاق نار، سلب سيارة، توجيه سلاح)
local AutoAllowed = { shooting = true, carjack = true, suspicious = true }
RegisterNetEvent('ar_dispatch:server:auto', function(kind, info)
    local src = source
    if not AutoAllowed[kind] then return end
    local key = src .. kind
    local cfg = Config.Auto[kind == 'suspicious' and 'aiming' or kind]
    local now = os.time()
    if Cooldowns[key] and now - Cooldowns[key] < ((cfg and cfg.cooldown) or 20) then return end
    Cooldowns[key] = now
    local coords, gender, P = sourceInfo(src)
    if P and isCop(P.PlayerData) and kind ~= 'carjack' then return end
    info = type(info) == 'table' and info or {}
    local details = {}
    if info.weapon then details[#details + 1] = { 'السلاح', tostring(info.weapon):sub(1, 40) } end
    if info.inVehicle then details[#details + 1] = { 'من داخل', 'مركبة' } end
    local vehicle
    if type(info.vehicle) == 'table' then
        vehicle = { model = tostring(info.vehicle.model or ''):sub(1, 40), plate = tostring(info.vehicle.plate or ''):sub(1, 12), color = tostring(info.vehicle.color or ''):sub(1, 30) }
    end
    Alert({ type = kind, coords = coords, gender = gender, details = details, vehicle = vehicle,
        message = kind == 'suspicious' and 'شخص يوجه سلاح على مواطن' or nil })
end)

-- البلاغات القديمة مال QBCore (بنوك، متاجر، مخدرات، مفاتيح السيارات...) تتحول هنا
local function classify(text)
    local s = tostring(text or ''):lower()
    local function has(...) for _, w in ipairs({ ... }) do if s:find(w, 1, true) then return true end end end
    if has('fleeca', 'paleto', 'pacific', 'bank', 'بنك') then return 'bank' end
    if has('jewel', 'vangelico', 'مجوهرات') then return 'jewelry' end
    if has('store', 'shop', '24/7', 'liquor', 'register', 'safe', 'متجر', 'محل') then return 'store' end
    if has('house', 'بيت') then return 'house' end
    if has('carjack') then return 'carjack' end
    if has('steal', 'theft', 'vehicle', 'سيارة') then return 'cartheft' end
    if has('drug', 'مخدرات') then return 'drugs' end
    if has('officer', 'ضابط') then return 'officer' end
    if has('استغاثة', 'distress', 'help') then return 'distress' end
    if has('suspic', 'مشبوه') then return 'suspicious' end
    if has('prison', 'jail', 'سجن') then return 'prison' end
    return 'general'
end

AddEventHandler('ar_dispatch:legacy', function(src, text, coords)
    local c, gender = coords, nil
    if src and src > 0 then
        local cc, g = sourceInfo(src)
        c, gender = c or cc, g
    end
    local t = classify(text)
    Alert({ type = t, coords = c, gender = gender, message = (t == 'general' or t == 'distress') and text or nil })
end)

-- سكربتات ثانية تكدر ترسل بلاغ: TriggerEvent('ar_dispatch:server:alert', { type='bank', coords=vector3(...) })
AddEventHandler('ar_dispatch:server:alert', function(data)
    if type(data) == 'table' then Alert(data) end
end)

-- مستجيب
RegisterNetEvent('ar_dispatch:server:respond', function(id)
    local P = QBCore.Functions.GetPlayer(source)
    if not P or not isCop(P.PlayerData) then return end
    for _, a in ipairs(Alerts) do
        if a.id == id then
            local name = officerName(P.PlayerData)
            for _, r in ipairs(a.responders) do if r == name then return end end
            a.responders[#a.responders + 1] = name
            broadcast('ar_dispatch:client:update', { id = id, responders = a.responders })
            return
        end
    end
end)

-- لما يسجل دوام ياخذ آخر البلاغات
RegisterNetEvent('ar_dispatch:server:sync', function()
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    if P and isCop(P.PlayerData) then TriggerClientEvent('ar_dispatch:client:sync', src, Alerts) end
end)

-- اختبار للأدمن: /testalert shooting
QBCore.Commands.Add('testalert', 'تجربة بلاغ (أدمن)', { { name = 'type', help = 'shooting / bank / store / cartheft / prison / suspicious ...' } }, false, function(source, args)
    local coords = GetEntityCoords(GetPlayerPed(source))
    Alert({ type = args[1] or 'shooting', coords = coords, gender = 'ذكر', details = { { 'تجربة', 'هذا بلاغ تجريبي' } } })
end, 'admin')

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(Cooldowns) do if k:sub(1, #src) == src then Cooldowns[k] = nil end end
end)
