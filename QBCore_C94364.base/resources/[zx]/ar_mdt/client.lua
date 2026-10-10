local QBCore = exports['qb-core']:GetCoreObject()
local isOpen, tablet = false, nil

-- طلبات للسيرفر برقم خاص لكل طلب (الرد يجي نص JSON)
local pending, nextId = {}, 0
local function request(name, data, cb)
    nextId = nextId + 1
    local id = nextId
    pending[id] = cb
    TriggerServerEvent('ar_mdt:req', id, name, data or {})
    SetTimeout(15000, function()
        if pending[id] then
            pending[id] = nil
            print(('^1[ar_mdt] %s: السيرفر ما رد خلال 15 ثانية^7'):format(name))
            cb(json.encode({ err = 'السيرفر ما رد (' .. name .. ')' }))
        end
    end)
end

RegisterNetEvent('ar_mdt:res', function(id, encoded)
    local cb = pending[id]
    if not cb then return end
    pending[id] = nil
    cb(encoded)
end)

local function startTablet()
    if not Config.Tablet then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local dict, model = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', `prop_cs_tablet`
    RequestAnimDict(dict)
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while (not HasAnimDictLoaded(dict) or not HasModelLoaded(model)) and GetGameTimer() < t do Wait(10) end
    tablet = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(tablet, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    TaskPlayAnim(ped, dict, 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
    SetModelAsNoLongerNeeded(model)
end

local function stopTablet()
    if tablet then
        DeleteEntity(tablet)
        tablet = nil
        StopAnimTask(PlayerPedId(), 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0)
    end
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTablet()
end

local function open()
    if isOpen then return close() end
    local pd = QBCore.Functions.GetPlayerData()
    if not pd.job or not Config.Jobs[pd.job.name] then return end
    if Config.NeedDuty and not pd.job.onduty then
        return QBCore.Functions.Notify('لازم تسجل دوام حتى تفتح الـ MDT', 'error')
    end
    if pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand) then return end
    request('init', {}, function(encoded)
        local res = json.decode(encoded)
        if not res or res.err then
            return QBCore.Functions.Notify(res and res.err or 'ما ينفتح الـ MDT', 'error')
        end
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = res.data })
        startTablet()
    end)
end

RegisterCommand(Config.Command, open, false)
RegisterKeyMapping(Config.Command, 'فتح MDT الأمن العام', 'keyboard', Config.Key)

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

-- كل طلبات الواجهة تروح للسيرفر من هنا
RegisterNUICallback('req', function(body, cb)
    request(body and body.name or '?', body and body.data, function(encoded)
        cb(encoded) -- نص JSON جاهز يروح للواجهة مثل ما هو
    end)
end)

-- البلاغات: GPS + موقعي على الخريطة + بلاغ جديد وهو فاتح الـ MDT
RegisterNUICallback('gps', function(d, cb)
    if d and d.coords then
        if GetResourceState('ar_dispatch') == 'started' then
            exports['ar_dispatch']:SetGps(d.id, d.coords)
        else
            SetNewWaypoint(d.coords.x + 0.0, d.coords.y + 0.0)
        end
        QBCore.Functions.Notify('انحدد الموقع على الـ GPS', 'success')
    end
    cb('ok')
end)

RegisterNUICallback('mypos', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    cb(json.encode({ x = c.x, y = c.y, z = c.z }))
end)

-- يحول أسماء الشوارع للبلاغات (الأسماء تنعرف بس بالكلاينت)
RegisterNUICallback('streets', function(list, cb)
    local out = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        local s1, s2 = GetStreetNameAtCoord(p.x + 0.0, p.y + 0.0, (p.z or 0) + 0.0)
        local a, b = GetStreetNameFromHashKey(s1), GetStreetNameFromHashKey(s2)
        local zone = GetLabelText(GetNameOfZone(p.x + 0.0, p.y + 0.0, (p.z or 0) + 0.0))
        out[#out + 1] = { street = (b ~= '' and (a .. ' / ' .. b) or a), zone = zone ~= 'NULL' and zone or '' }
    end
    cb(json.encode(out))
end)

RegisterNetEvent('ar_dispatch:client:alert', function(a)
    if isOpen then SendNUIMessage({ action = 'dispatch', alert = a }) end
end)

-- يسكر إذا مات أو تغيرت وظيفته
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if isOpen and not Config.Jobs[job.name] then close() end
end)

CreateThread(function()
    while true do
        if isOpen then
            local md = QBCore.Functions.GetPlayerData().metadata
            if md and (md.isdead or md.inlaststand) then close() end
            Wait(500)
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    stopTablet()
end)
