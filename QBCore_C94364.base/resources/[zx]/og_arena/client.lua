-- الأرينا (كل واحد لنفسه)
local QBCore = exports['qb-core']:GetCoreObject()
local mode, A = nil, nil
local dying = false
local lastAttacker = nil
local spawns = {}
local floorTop = 0.0

local function buildArena()
    Build.clear()
    spawns = {}
    local C = Config.Sky
    floorTop = C.z
    local hw = Build.floor(C, A.size, A.size)
    Build.walls(C, hw, hw)

    -- السواتر: توزيع ثابت (نفس الشكل عند الكل) بالـ seed
    local covers = Build.covers()
    math.randomseed(A.seed)
    local cell = 7.0
    local n = math.floor((hw * 2 - 6.0) / cell)
    local start = -((n - 1) * cell) / 2
    for i = 0, n - 1 do
        for j = 0, n - 1 do
            local x, y = C.x + start + i * cell, C.y + start + j * cell
            if #covers > 0 and math.random() < A.cover then
                local m = covers[math.random(1, #covers)]
                Build.place(m, x + math.random(-15, 15) / 10, y + math.random(-15, 15) / 10, C.z, math.random(0, 3) * 90.0 + math.random(-10, 10))
                if A.towers and m == Config.WallModels[1] and math.random() < 0.5 then
                    local s = Build.size(m)
                    Build.place(m, x, y, C.z + s.z, math.random(0, 3) * 90.0) -- أبراج للسنايبر
                end
            else
                spawns[#spawns + 1] = vector3(x, y, C.z + 0.2)
            end
        end
    end
    if #spawns == 0 then spawns[1] = vector3(C.x, C.y, C.z + 0.2) end
    math.randomseed(GetGameTimer() + GetPlayerServerId(PlayerId()))
end

local function spawn()
    lastAttacker = nil
    Build.spawnAt(spawns[math.random(1, #spawns)], math.random(0, 359) + 0.0, A.weapon, function() return mode ~= nil end)
end

RegisterNetEvent('og_arena:enter', function(m)
    mode, A = m, Config.Arenas[m]
    dying = false
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, Config.Sky.x, Config.Sky.y, Config.Sky.z + 5.0, false, false, false, false)
    buildArena()
    Wait(300)
    FreezeEntityPosition(ped, false)
    SendNUIMessage({ action = 'enter', mode = m, label = A.label, en = A.en, place = A.place, color = A.color })
    spawn()
    QBCore.Functions.Notify(('دخلت أرينا %s — ESC أو /%s حتى تطلع'):format(A.label, Config.LeaveCommand), 'success', 7000)
end)

RegisterNetEvent('og_arena:exit', function(pos)
    local w = A and A.weapon
    mode, A = nil, nil
    SendNUIMessage({ action = 'exit' })
    Build.restore(pos, w)
end)

RegisterNetEvent('og_arena:feed', function(d) SendNUIMessage({ action = 'feed', d = d, me = GetPlayerServerId(PlayerId()) }) end)
RegisterNetEvent('og_arena:board', function(list) SendNUIMessage({ action = 'board', list = list, me = GetPlayerServerId(PlayerId()) }) end)

AddEventHandler('gameEventTriggered', function(name, args)
    if not mode or name ~= 'CEventNetworkEntityDamage' or args[1] ~= PlayerPedId() then return end
    local attacker = args[2]
    if attacker and attacker ~= 0 and IsEntityAPed(attacker) and IsPedAPlayer(attacker) then
        local pl = NetworkGetPlayerIndexFromPed(attacker)
        if pl and pl ~= -1 then lastAttacker = GetPlayerServerId(pl) end
    end
end)

local function died()
    if dying then return end
    dying = true
    TriggerServerEvent('og_arena:died', lastAttacker)
    SetTimeout(Config.RespawnTime, function()
        if not mode then dying = false return end
        Build.revive()
        Wait(300)
        if mode then spawn() end
        dying = false
    end)
end

CreateThread(function()
    while true do
        if mode then
            local ped = PlayerPedId()
            local md = QBCore.Functions.GetPlayerData().metadata or {}
            if not dying then
                if IsEntityDead(ped) or md.inlaststand or md.isdead then died()
                elseif GetEntityCoords(ped).z < floorTop - 12.0 then died() -- وگع من الساحة
                elseif not HasPedGotWeapon(ped, A.weapon, false) then Build.weaponOn(ped, A.weapon) end
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if mode then
            DisplayRadar(false)
            DisableControlAction(0, 23, true)   -- ركوب سيارة
            DisableControlAction(0, 37, true)   -- عجلة الأسلحة
            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('InArena', function() return mode ~= nil end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    Build.clear()
    if mode then
        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        ResetEntityAlpha(ped)
        DisplayRadar(true)
        DoScreenFadeIn(0)
    end
end)
