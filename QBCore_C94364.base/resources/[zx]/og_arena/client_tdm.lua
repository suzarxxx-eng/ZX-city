-- تيد ام: فريقين (أحمر / أزرق) بماب خاص بالسما
local QBCore = exports['qb-core']:GetCoreObject()
local T = Config.Tdm
local M = nil            -- { weapon, team, roster, target }
local dying, ended = false, false
local lastAttacker = nil
local bases = { red = {}, blue = {} }
local floorTop, hl = 0.0, 0.0
local lastHealth, lastArmor = 200, 100

local COLORS = { red = { 255, 61, 94 }, blue = { 47, 140, 255 } }

local function buildMap()
    Build.clear()
    bases = { red = {}, blue = {} }
    local C = T.Sky
    floorTop = C.z
    local hw
    hw, hl = Build.floor(C, T.Width, T.Length)
    Build.walls(C, hw, hl)

    -- السواتر بالنص الجنوبي، ونفسها بالمراية للشمالي (عدالة للفريقين)
    local covers = Build.covers()
    math.randomseed(T.Seed)
    local cell = 6.5
    local nx = math.floor((hw * 2 - 5.0) / cell)
    local sx = -((nx - 1) * cell) / 2
    local y = -hl + T.BaseDepth + cell / 2
    while y < -1.0 do
        for i = 0, nx - 1 do
            local x = sx + i * cell
            if #covers > 0 and math.random() < T.Cover then
                local m = covers[math.random(1, #covers)]
                local h = math.random(0, 3) * 90.0
                local jx, jy = math.random(-12, 12) / 10, math.random(-12, 12) / 10
                Build.place(m, C.x + x + jx, C.y + y + jy, C.z, h)
                Build.place(m, C.x - x - jx, C.y - y - jy, C.z, h + 180.0)
            end
        end
        y = y + cell
    end
    -- خط النص: ساتر واطي يقسم الساحة
    if #covers > 0 then
        for i = 0, nx - 1, 2 do Build.place(covers[1], C.x + sx + i * cell, C.y, C.z, 90.0) end
    end
    -- مناطق النزول
    for i = 0, 3 do
        for j = 0, 2 do
            local x = (i - 1.5) * (hw * 0.4)
            local d = 3.0 + j * 3.0
            bases.red[#bases.red + 1] = vector3(C.x + x, C.y - hl + d, C.z + 0.2)
            bases.blue[#bases.blue + 1] = vector3(C.x + x, C.y + hl - d, C.z + 0.2)
        end
    end
    math.randomseed(GetGameTimer() + GetPlayerServerId(PlayerId()))
end

local function spawn()
    lastAttacker = nil
    local list = bases[M.team]
    local h = M.team == 'red' and 0.0 or 180.0
    Build.spawnAt(list[math.random(1, #list)], h, M.weapon, function() return M ~= nil end)
end

-- فرق اللاعبين (حتى ما يضربون بعض)
local function groups()
    local _, red = AddRelationshipGroup('OG_TDM_RED')
    local _, blue = AddRelationshipGroup('OG_TDM_BLUE')
    SetRelationshipBetweenGroups(1, red, red)
    SetRelationshipBetweenGroups(1, blue, blue)
    SetRelationshipBetweenGroups(5, red, blue)
    SetRelationshipBetweenGroups(5, blue, red)
    return { red = red, blue = blue }
end
local G = nil

local function teamOf(serverId) return M and M.roster[tostring(serverId)] end

RegisterNetEvent('og_tdm:start', function(d)
    local w = T.Weapons[d.weapon]
    M = { weapon = w.hash, wkey = d.weapon, team = d.team, roster = d.roster, target = d.target }
    dying, ended = false, false
    G = G or groups()
    TriggerEvent('og_menu:forceClose')
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, T.Sky.x, T.Sky.y, T.Sky.z + 5.0, false, false, false, false)
    buildMap()
    Wait(300)
    FreezeEntityPosition(ped, false)
    SendNUIMessage({ action = 'tdmStart', team = d.team, target = d.target, seconds = d.seconds, weapon = w.label })
    spawn()
end)

RegisterNetEvent('og_tdm:score', function(s) if M then SendNUIMessage({ action = 'tdmScore', score = s }) end end)
RegisterNetEvent('og_tdm:feed', function(d) if M then SendNUIMessage({ action = 'tdmFeed', d = d, me = GetPlayerServerId(PlayerId()) }) end end)

RegisterNetEvent('og_tdm:ended', function(d)
    if not M then return end
    ended = true
    SetEntityInvincible(PlayerPedId(), true)
    SendNUIMessage({ action = 'tdmEnd', d = d, team = M.team, me = GetPlayerServerId(PlayerId()) })
    PlaySoundFrontend(-1, d.winner == M.team and 'MP_WAVE_COMPLETE' or 'LOSER', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

RegisterNetEvent('og_tdm:finish', function(pos)
    local w = M and M.weapon
    M = nil
    ended = false
    SendNUIMessage({ action = 'tdmExit' })
    SetPedRelationshipGroupHash(PlayerPedId(), `PLAYER`)
    Build.restore(pos, w)
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if not M or name ~= 'CEventNetworkEntityDamage' or args[1] ~= PlayerPedId() then return end
    local attacker = args[2]
    if attacker and attacker ~= 0 and IsEntityAPed(attacker) and IsPedAPlayer(attacker) then
        local pl = NetworkGetPlayerIndexFromPed(attacker)
        local sid = pl and pl ~= -1 and GetPlayerServerId(pl)
        if sid and sid ~= GetPlayerServerId(PlayerId()) and teamOf(sid) == M.team then
            -- ضربة من فريقي: نرجع الدم
            local ped = PlayerPedId()
            if not IsEntityDead(ped) then SetEntityHealth(ped, lastHealth) SetPedArmour(ped, lastArmor) end
            return
        end
        if sid then lastAttacker = sid end
    end
end)

local function died()
    if dying or ended then return end
    dying = true
    TriggerServerEvent('og_tdm:died', lastAttacker)
    SetTimeout(Config.RespawnTime, function()
        if not M then dying = false return end
        Build.revive()
        Wait(300)
        if M and not ended then spawn() end
        dying = false
    end)
end

-- المراقبة
CreateThread(function()
    while true do
        if M then
            local ped = PlayerPedId()
            local md = QBCore.Functions.GetPlayerData().metadata or {}
            if not dying and not ended then
                if IsEntityDead(ped) or md.inlaststand or md.isdead then died()
                elseif GetEntityCoords(ped).z < floorTop - 12.0 then died()
                else
                    lastHealth, lastArmor = GetEntityHealth(ped), GetPedArmour(ped)
                    if not HasPedGotWeapon(ped, M.weapon, false) then Build.weaponOn(ped, M.weapon) end
                end
            end
            -- الفرق
            SetPedRelationshipGroupHash(ped, G[M.team])
            SetCanAttackFriendly(ped, false, false)
            for sid, team in pairs(M.roster) do
                local pl = GetPlayerFromServerId(tonumber(sid))
                if pl ~= -1 then
                    local p = GetPlayerPed(pl)
                    if p ~= ped and DoesEntityExist(p) then SetPedRelationshipGroupHash(p, G[team]) end
                end
            end
            Wait(200)
        else
            Wait(1000)
        end
    end
end)

-- علامات: مناطق الفريقين + سهم فوك راس أصحابي
CreateThread(function()
    while true do
        if M then
            DisplayRadar(false)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 37, true)
            if ended then DisableAllControlActions(0) EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) end
            local C = T.Sky
            for team, c in pairs(COLORS) do
                local by = team == 'red' and (C.y - hl + T.BaseDepth / 2) or (C.y + hl - T.BaseDepth / 2)
                DrawMarker(1, C.x, by, C.z - 0.95, 0, 0, 0, 0, 0, 0, T.Width * 0.9, T.BaseDepth, 0.6, c[1], c[2], c[3], 45, false, false, 2, false, nil, nil, false)
            end
            local me = PlayerPedId()
            local c = COLORS[M.team]
            for sid, team in pairs(M.roster) do
                if team == M.team then
                    local pl = GetPlayerFromServerId(tonumber(sid))
                    if pl ~= -1 then
                        local p = GetPlayerPed(pl)
                        if p ~= me and DoesEntityExist(p) and not IsEntityDead(p) then
                            local pos = GetEntityCoords(p)
                            DrawMarker(2, pos.x, pos.y, pos.z + 1.25, 0, 0, 0, 180.0, 0, 0, 0.28, 0.28, 0.28, c[1], c[2], c[3], 210, true, true, 2, false, nil, nil, false)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('InTdm', function() return M ~= nil end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and M then
        SetEntityInvincible(PlayerPedId(), false)
        ResetEntityAlpha(PlayerPedId())
        DisplayRadar(true)
        DoScreenFadeIn(0)
    end
end)
