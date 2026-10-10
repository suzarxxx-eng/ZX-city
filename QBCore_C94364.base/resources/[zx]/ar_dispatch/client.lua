local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local lastAlert = nil
local Blips = {}

local function isCop()
    local j = PlayerData.job
    return j and Config.Jobs[j.name] and j.onduty
end

local function refresh()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refresh()
    if isCop() then TriggerServerEvent('ar_dispatch:server:sync') end
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    local was = isCop()
    PlayerData.job = job
    if isCop() and not was then TriggerServerEvent('ar_dispatch:server:sync') end
    if not isCop() then SendNUIMessage({ action = 'clear' }) end
end)
RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if PlayerData.job then PlayerData.job.onduty = duty end
    if duty and isCop() then TriggerServerEvent('ar_dispatch:server:sync') end
end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(pd) PlayerData = pd end)
AddEventHandler('onResourceStart', function(r) if r == GetCurrentResourceName() then refresh() end end)
CreateThread(function() Wait(1000) refresh() end)

------------------------------------------------------------------
-- استلام البلاغ
------------------------------------------------------------------
local function streetOf(c)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local a, b = GetStreetNameFromHashKey(s1), GetStreetNameFromHashKey(s2)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local street = a
    if b and b ~= '' then street = street .. ' / ' .. b end
    return street, (zone ~= 'NULL' and zone or '')
end

local function addBlips(a)
    local def = Config.Types[a.type] or Config.Types.general
    local c = a.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, def.blip.sprite)
    SetBlipColour(blip, def.blip.color)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipHighDetail(blip, true)
    if a.priority >= 3 then SetBlipFlashes(blip, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(a.code .. ' - ' .. a.title)
    EndTextCommandSetBlipName(blip)

    local radius = AddBlipForRadius(c.x, c.y, c.z, a.priority >= 3 and 90.0 or 55.0)
    SetBlipColour(radius, def.blip.color)
    SetBlipAlpha(radius, 110)
    SetBlipHighDetail(radius, true)

    Blips[a.id] = { blip, radius }
    CreateThread(function()
        local total = Config.BlipTime * 1000
        local start = GetGameTimer()
        while Blips[a.id] do
            local left = 1.0 - (GetGameTimer() - start) / total
            if left <= 0 then break end
            SetBlipAlpha(radius, math.floor(110 * left))
            if left < 0.3 then SetBlipAlpha(blip, math.floor(255 * left / 0.3)) end
            Wait(1000)
        end
        if Blips[a.id] then
            RemoveBlip(blip)
            RemoveBlip(radius)
            Blips[a.id] = nil
        end
    end)
end

local function prepare(a)
    local street, zone = streetOf(a.coords)
    a.street, a.zone = street, zone
    local me = GetEntityCoords(PlayerPedId())
    a.dist = math.floor(#(me - vector3(a.coords.x, a.coords.y, a.coords.z)))
    return a
end

RegisterNetEvent('ar_dispatch:client:alert', function(a)
    if not isCop() then return end
    prepare(a)
    lastAlert = a
    SendNUIMessage({ action = 'alert', alert = a, showTime = Config.ShowTime, key = Config.GpsKey })
    addBlips(a)
    if Config.Sound then
        if a.priority >= 3 then
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
            Wait(250)
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
        else
            PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
        end
    end
end)

RegisterNetEvent('ar_dispatch:client:update', function(d)
    if lastAlert and lastAlert.id == d.id then lastAlert.responders = d.responders end
    SendNUIMessage({ action = 'update', id = d.id, responders = d.responders })
end)

RegisterNetEvent('ar_dispatch:client:sync', function(list)
    if list and list[1] then lastAlert = prepare(list[1]) end
end)

-- G: GPS على آخر بلاغ + أسجل مستجيب
local function gps(a)
    if not a then return QBCore.Functions.Notify('ماكو بلاغات', 'error') end
    SetNewWaypoint(a.coords.x, a.coords.y)
    TriggerServerEvent('ar_dispatch:server:respond', a.id)
    SendNUIMessage({ action = 'responding', id = a.id })
    QBCore.Functions.Notify(('انحدد الموقع: %s - %s'):format(a.code, a.title), 'success')
end

RegisterCommand('+dispatchgps', function()
    if not isCop() or IsPauseMenuActive() then return end
    gps(lastAlert)
end, false)
RegisterCommand('-dispatchgps', function() end, false)
RegisterKeyMapping('+dispatchgps', 'تحديد موقع آخر بلاغ', 'keyboard', Config.GpsKey)

-- للـ MDT
exports('SetGps', function(id, coords)
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        if id then TriggerServerEvent('ar_dispatch:server:respond', id) end
    end
end)

------------------------------------------------------------------
-- الكشف التلقائي (يشتغل عند كل اللاعبين)
------------------------------------------------------------------
local ignore = {}
for _, w in ipairs(Config.IgnoreWeapons) do ignore[w] = true end

local function inNoShootZone(c)
    for _, z in ipairs(Config.NoShootZones) do
        if #(c - z.coords) <= z.radius then return true end
    end
    return false
end

local function roll(chance) return math.random(1, 100) <= (chance or 100) end

local function vehInfo(veh)
    if not veh or veh == 0 then return nil end
    local model = GetEntityModel(veh)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if name == 'NULL' then name = GetDisplayNameFromVehicleModel(model) end
    return { model = name, plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') }
end

local lastSent = {}
local function send(kind, info, cooldown)
    local now = GetGameTimer()
    if lastSent[kind] and now - lastSent[kind] < cooldown * 1000 then return end
    lastSent[kind] = now
    TriggerServerEvent('ar_dispatch:server:auto', kind, info)
end

-- إطلاق نار
CreateThread(function()
    local cfg = Config.Auto.shooting
    if not cfg.enabled then return end
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) and not isCop() and not LocalPlayer.state.arena then -- الأرينا ما تطلع بلاغات
            Wait(0)
            if IsPedShooting(ped) then
                local weapon = GetSelectedPedWeapon(ped)
                local c = GetEntityCoords(ped)
                if not ignore[weapon] and not IsPedCurrentWeaponSilenced(ped) and not inNoShootZone(c) and roll(cfg.chance) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    send('shooting', { inVehicle = veh ~= 0, vehicle = veh ~= 0 and vehInfo(veh) or nil }, cfg.cooldown)
                    Wait(1000)
                end
            end
        else
            Wait(500)
        end
    end
end)

-- سلب سيارة بالقوة
CreateThread(function()
    local cfg = Config.Auto.carjack
    if not cfg.enabled then return end
    while true do
        local ped = PlayerPedId()
        if IsPedJacking(ped) then
            local veh = GetVehiclePedIsTryingToEnter(ped)
            if veh == 0 then veh = GetVehiclePedIsIn(ped, false) end
            if roll(cfg.chance) then send('carjack', { vehicle = vehInfo(veh) }, cfg.cooldown) end
            Wait(5000)
        end
        Wait(300)
    end
end)

-- توجيه سلاح على شخص = حركة مشبوهة
CreateThread(function()
    local cfg = Config.Auto.aiming
    if not cfg.enabled then return end
    local aimed = 0
    while true do
        Wait(500)
        local pid = PlayerId()
        if not isCop() and not LocalPlayer.state.arena and IsPlayerFreeAiming(pid) then
            local ok, ent = GetEntityPlayerIsFreeAimingAt(pid)
            if ok and ent and DoesEntityExist(ent) and IsEntityAPed(ent) and IsPedHuman(ent) and not IsPedDeadOrDying(ent, true) then
                aimed = aimed + 0.5
                if aimed >= cfg.seconds then
                    aimed = -30 -- ما يتكرر بسرعة
                    if roll(cfg.chance) then send('suspicious', {}, cfg.cooldown) end
                end
            else
                aimed = math.max(math.min(aimed, 0), aimed - 0.5)
            end
        elseif aimed > 0 then
            aimed = 0
        elseif aimed < 0 then
            aimed = aimed + 0.5
        end
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for _, b in pairs(Blips) do RemoveBlip(b[1]) RemoveBlip(b[2]) end
end)
