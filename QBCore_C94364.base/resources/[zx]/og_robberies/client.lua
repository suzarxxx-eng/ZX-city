-- og_robberies client: no blips. Idle cost ~0: sleeps 1s unless a spot is within MarkerDistance.

local allSpots = Config.Locations
local spots = {}                  -- only spots the server says are enabled (filled by og_robberies:client:spots)
if not Config.OnlyConfiguredSpots then for i = 1, #allSpots do spots[i] = allSpots[i] end end
local active = nil            -- { id, token }
local promptShown = false

local function nui(msg) SendNUIMessage(msg) end

local function showPrompt(show, text)
    if show == promptShown then return end
    promptShown = show
    nui({ type = 'prompt', show = show, key = 'E', text = text })
end

RegisterNetEvent('og_robberies:client:notify', function(text, kind)
    nui({ type = 'notify', text = text, kind = kind })
end)

local function stopAction(cancelled)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetNuiFocus(false, false)
    nui({ type = 'game', show = false })
    if cancelled and active then
        TriggerServerEvent('og_robberies:server:cancel', active.token)
        nui({ type = 'notify', text = Config.Text.cancel, kind = 'warn' })
    end
    active = nil
end

-- Lockpick challenge result comes back from the NUI: 'success' | 'fail' | 'cancel'
RegisterNUICallback('gameResult', function(data, cb)
    cb('ok')
    if not active then return end
    local tok = active.token
    if data.result == 'success' then
        stopAction(false)
        TriggerServerEvent('og_robberies:server:finish', tok)
    elseif data.result == 'fail' then
        stopAction(false)
        TriggerServerEvent('og_robberies:server:fail', tok)
    else
        stopAction(true)
    end
end)

RegisterNetEvent('og_robberies:client:begin', function(id, token, game)
    active = { id = id, token = token }
    local ped = PlayerPedId()
    local spot
    for _, s in ipairs(allSpots) do if s.id == id then spot = s break end end

    local dict = 'mini@safe_cracking'
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 3000 do Wait(10) end
    TaskPlayAnim(ped, dict, 'idle_base', 8.0, -8.0, -1, 1, 0.0, false, false, false)

    SetNuiFocus(true, false) -- keyboard only, no cursor
    nui({ type = 'game', show = true, pins = game.pins, lives = game.lives, zone = game.zone, speed = game.speed, label = Config.Text.progress })

    -- watch for the player dying, ragdolling or walking away while the challenge is open
    CreateThread(function()
        while active and active.token == token do
            Wait(100)
            local p = PlayerPedId()
            if IsEntityDead(p) or IsPedRagdoll(p) or #(GetEntityCoords(p) - spot.coords) > Config.ServerMaxDistance then
                stopAction(true)
                break
            end
        end
    end)
end)
-- Spot positions saved in-game (/rob_setspot) override the config
RegisterNetEvent('og_robberies:client:spots', function(list)
    for i = #spots, 1, -1 do spots[i] = nil end
    for i = 1, #allSpots do
        local c = list[allSpots[i].id]
        if c then
            allSpots[i].coords = vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
            spots[#spots + 1] = allSpots[i]
        end
    end
end)
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('og_robberies:server:getSpots')
end)
-- Proximity loop: slow scan, fast drawing only when close
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local nearest, nearestDist = nil, 1e9
        for i = 1, #spots do
            local d = #(pos - spots[i].coords)
            if d < nearestDist then nearest, nearestDist = spots[i], d end
        end

        if nearest and nearestDist <= Config.MarkerDistance and not active then
            -- close: draw marker and handle the prompt at frame rate
            local c = Config.MarkerColor
            while true do
                Wait(0)
                if active then break end
                pos = GetEntityCoords(PlayerPedId())
                local d = #(pos - nearest.coords)
                if d > Config.MarkerDistance + 1.0 then break end
                DrawMarker(27, nearest.coords.x, nearest.coords.y, nearest.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.9, 0.9, 0.6, c.r, c.g, c.b, c.a, false, true, 2, false, nil, nil, false)
                if d <= Config.InteractDistance then
                    showPrompt(true, Config.Text.prompt .. ' · ' .. nearest.label)
                    if IsControlJustPressed(0, Config.InteractKey) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        TriggerServerEvent('og_robberies:server:start', nearest.id)
                        Wait(500)
                    end
                else
                    showPrompt(false)
                end
            end
            showPrompt(false)
        else
            showPrompt(false)
            -- far away: sleep longer the further we are
            Wait(nearestDist > 150.0 and 2000 or 750)
        end
    end
end)

-- Debug helpers (only when Config.Debug = true): /rob_here prints your coords on the server console
if Config.Debug then
    RegisterCommand('rob_here', function()
        local c = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('og_robberies:server:coords', { x = c.x, y = c.y, z = c.z })
        nui({ type = 'notify', text = ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z), kind = 'info' })
    end, false)
    CreateThread(function()
        while true do
            Wait(0)
            for i = 1, #spots do
                local s = spots[i]
                DrawMarker(28, s.coords.x, s.coords.y, s.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 0, 0, 120, false, true, 2, false, nil, nil, false)
            end
        end
    end)
end

