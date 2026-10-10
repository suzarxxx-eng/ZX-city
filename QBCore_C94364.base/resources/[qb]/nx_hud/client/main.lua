-- nx_hud client
-- Design rule: every loop computes values locally and only calls SendNUIMessage
-- when something changed. That is what keeps resmon near 0.00ms.

local Framework = Config.Framework
if Framework == 'auto' then
    if GetResourceState('qb-core') == 'started' then Framework = 'qb'
    elseif GetResourceState('es_extended') == 'started' then Framework = 'esx'
    else Framework = 'standalone' end
end

local QBCore
if Framework == 'qb' then QBCore = exports['qb-core']:GetCoreObject() end

local KVP_KEY = 'nx_hud:settings'
local hunger, thirst = 100, 100
local belt, menuOpen, nuiReady = false, false, false

local function send(data) SendNUIMessage(data) end
local function clamp(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end

-- ---------------------------------------------------------------------------
-- Needs (hunger / thirst) per framework
-- ---------------------------------------------------------------------------
if Framework == 'qb' then
    local function pull(pd)
        local m = pd and pd.metadata
        if m then hunger, thirst = m.hunger or 100, m.thirst or 100 end
    end
    AddEventHandler('QBCore:Player:SetPlayerData', pull)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() pull(QBCore.Functions.GetPlayerData()) end)
    CreateThread(function() pull(QBCore.Functions.GetPlayerData()) end)
elseif Framework == 'esx' then
    AddEventHandler('esx_status:onTick', function(status)
        for i = 1, #status do
            local s = status[i]
            if s.name == 'hunger' then hunger = s.percent
            elseif s.name == 'thirst' then thirst = s.percent end
        end
    end)
end

-- Standalone / custom needs scripts: exports['nx_hud']:SetNeeds(hunger, thirst)
exports('SetNeeds', function(h, t) hunger, thirst = h or hunger, t or thirst end)

-- ---------------------------------------------------------------------------
-- NUI bootstrap + persistence (KVP lives on the player's PC)
-- ---------------------------------------------------------------------------
RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    send({
        action = 'init',
        settings = GetResourceKvpString(KVP_KEY), -- JSON string or nil
        maxSpeed = Config.MaxSpeedKmh,
    })
    cb(1)
end)

RegisterNUICallback('save', function(data, cb)
    if type(data.json) == 'string' and #data.json < 4096 then
        SetResourceKvp(KVP_KEY, data.json)
    end
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('cinematic', function(data, cb)
    if not Config.HideMinimap then DisplayRadar(not data.on) end -- minimap follows the bars
    cb(1)
end)

local function toggleMenu()
    if not nuiReady then return end
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    send({ action = 'menu', open = menuOpen })
end

RegisterCommand('hudmenu', toggleMenu, false)
RegisterKeyMapping('hudmenu', 'Open HUD settings', 'keyboard', Config.OpenKey)

RegisterCommand('cinematic', function() send({ action = 'toggleCinematic' }) end, false)

-- ---------------------------------------------------------------------------
-- Status loop (on foot): health, armor, hunger, thirst, stamina
-- ---------------------------------------------------------------------------
CreateThread(function()
    local lastKey
    while true do
        if Config.HideMinimap then DisplayRadar(false) end -- cheap native; GTA re-enables it when entering vehicles
        local ped = PlayerPedId()
        local paused = IsPauseMenuActive()
        local dead = IsEntityDead(ped)

        local maxHp = math.max(1, GetEntityMaxHealth(ped) - 100)
        local hp = dead and 0 or clamp((GetEntityHealth(ped) - 100) / maxHp * 100)
        local armor = clamp(GetPedArmour(ped))
        -- GetPlayerSprintStaminaRemaining returns the % *used*, so invert it.
        local stamina = clamp(100 - GetPlayerSprintStaminaRemaining(PlayerId()))
        local h, t = clamp(hunger), clamp(thirst)

        local key = hp .. '|' .. armor .. '|' .. h .. '|' .. t .. '|' .. stamina .. '|' .. (paused and 1 or 0)
        if key ~= lastKey then
            lastKey = key
            send({ action = 'status', health = hp, armor = armor, hunger = h, thirst = t,
                   stamina = stamina, visible = not paused })
        end
        Wait(Config.StatusInterval)
    end
end)

-- ---------------------------------------------------------------------------
-- Seatbelt
-- ---------------------------------------------------------------------------
-- No belts on bikes (8), cycles (13), boats (14), helis (15), planes (16)
local noBelt = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true }

local function setBelt(state)
    belt = state
    if belt then
        PlaySoundFrontend(-1, 'Faster_Click', 'RESET_PED_RADIO_SOUNDSET', true)
        -- Block exiting the vehicle only while buckled (thread dies when unbuckled)
        CreateThread(function()
            while belt do
                DisableControlAction(0, 75, true)
                Wait(0)
            end
        end)
    else
        PlaySoundFrontend(-1, 'Faster_Click', 'RESET_PED_RADIO_SOUNDSET', true)
    end
end

RegisterCommand('nx_seatbelt', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or noBelt[GetVehicleClass(veh)] then return end
    setBelt(not belt)
end, false)
RegisterKeyMapping('nx_seatbelt', 'Toggle seatbelt', 'keyboard', Config.SeatbeltKey)

exports('IsSeatbeltOn', function() return belt end)

-- ---------------------------------------------------------------------------
-- Vehicle loop. Sleeps 500ms when on foot.
-- ---------------------------------------------------------------------------
local function getFuel(veh)
    local st = Entity(veh).state.fuel -- ox_fuel & others
    if st then return st end
    return GetVehicleFuelLevel(veh)   -- LegacyFuel / native
end

CreateThread(function()
    local wasIn, lastKey, prevSpeed = false, nil, 0
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            wasIn = true
            local class = GetVehicleClass(veh)
            local speed = math.floor(GetEntitySpeed(veh) * 3.6) -- km/h; NUI converts to mph
            local rpm = math.floor(GetVehicleCurrentRpm(veh) * 100)
            local gear = GetVehicleCurrentGear(veh)
            local g
            if gear == 0 then
                g = GetEntitySpeedVector(veh, true).y < -0.5 and 'R' or 'N'
            else
                g = tostring(gear)
            end
            local fuel = clamp(getFuel(veh))
            local engine = clamp(GetVehicleEngineHealth(veh) / 10)
            local body = clamp(GetVehicleBodyHealth(veh) / 10)
            local canBelt = not noBelt[class]
            local warn = canBelt and not belt and speed >= Config.SeatbeltWarnSpeed

            if Config.EjectOnCrash and canBelt and not belt and prevSpeed - speed >= Config.EjectDecel then
                local c = GetEntityCoords(veh)
                SetEntityCoords(ped, c.x, c.y, c.z + 1.0, false, false, false, false)
                SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
                SetEntityVelocity(ped, GetEntityVelocity(veh))
            end
            prevSpeed = speed

            local key = speed .. '|' .. rpm .. '|' .. g .. '|' .. fuel .. '|' .. engine .. '|' .. body
                .. '|' .. (belt and 1 or 0) .. '|' .. (warn and 1 or 0) .. '|' .. (canBelt and 1 or 0)
            if key ~= lastKey then
                lastKey = key
                send({ action = 'vehicle', show = true, speed = speed, rpm = rpm, gear = g, fuel = fuel,
                       engine = engine, body = body, belt = belt, warn = warn, canBelt = canBelt })
            end
            Wait(Config.VehicleInterval)
        else
            if wasIn then
                wasIn, lastKey, prevSpeed = false, nil, 0
                if belt then belt = false end
                send({ action = 'vehicle', show = false })
            end
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Duty widget (data comes from the server so the count is real-time)
-- ---------------------------------------------------------------------------
RegisterNetEvent('nx_hud:job', function(data) send({ action = 'job', data = data }) end)

-- Safety: never leave the cursor stuck if the resource restarts with the menu open
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        DisplayRadar(true)
    end
end)
