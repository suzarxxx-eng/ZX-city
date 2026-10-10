local trackerBlip = nil
local trackingActive = false

local function applyTrackerVisual(enabled)
    local item = Config.Tracker.accessoryItem or 13
    local texture = Config.Tracker.accessoryTexture or 0

    if enabled then
        TriggerEvent('qb-clothing:client:loadOutfit', {
            outfitData = {
                ['accessory'] = { item = item, texture = texture }
            }
        })
        SetPedComponentVariation(PlayerPedId(), 7, item, texture, 0)
        return
    end

    TriggerServerEvent('qb-clothes:loadPlayerSkin')
end

local function clearTrackerBlip()
    trackingActive = false
    if trackerBlip then
        RemoveBlip(trackerBlip)
        trackerBlip = nil
    end
end

local function setTrackerBlip(coords)
    if not coords then return end
    local x, y, z = coords.x, coords.y, coords.z
    if trackerBlip then
        SetBlipCoords(trackerBlip, x, y, z)
    else
        trackerBlip = AddBlipForCoord(x, y, z)
        SetBlipSprite(trackerBlip, 458)
        SetBlipColour(trackerBlip, 1)
        SetBlipDisplay(trackerBlip, 4)
        SetBlipScale(trackerBlip, 1.1)
        SetBlipAsShortRange(trackerBlip, false)
        SetBlipFlashes(trackerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Lang:t('info.ankle_location'))
        EndTextCommandSetBlipName(trackerBlip)
    end
    SetBlipRoute(trackerBlip, true)
    SetBlipRouteColour(trackerBlip, 1)
    SetNewWaypoint(x, y)
end

RegisterNetEvent('police:client:CheckDistance', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        TriggerServerEvent('police:server:SetTracker', GetPlayerServerId(player))
    else
        QBCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:client:SetTracker', function(bool)
    applyTrackerVisual(bool)
end)

RegisterNetEvent('police:client:SendTrackerLocation', function(requestId)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('police:server:SendTrackerLocation', coords, requestId)
end)

RegisterNetEvent('police:client:TrackerMessage', function(msg, coords, isUpdate)
    if msg and not isUpdate then
        PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
        QBCore.Functions.Notify(msg, 'police')
    end
    trackingActive = true
    setTrackerBlip(coords)
end)

RegisterNetEvent('police:client:ClearTrackerBlip', function()
    clearTrackerBlip()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clearTrackerBlip()
    end
end)
