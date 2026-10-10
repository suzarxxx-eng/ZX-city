local open, crafting = false, false

-- ===================== الواجهة =====================
RegisterNetEvent('og_crafting:show', function(data)
    if not open then
        open = true
        SetNuiFocus(true, true)
    end
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('og_crafting:refresh', function()
    crafting = false
    ClearPedTasks(PlayerPedId())
    SendNUIMessage({ action = 'stop' })
    if open then TriggerServerEvent('og_crafting:open') end
end)

local function stopCraft(cancel)
    if not crafting then return end
    crafting = false
    ClearPedTasks(PlayerPedId())
    if cancel then
        TriggerServerEvent('og_crafting:cancel')
        SendNUIMessage({ action = 'stop' })
    end
end

local function close()
    stopCraft(true)
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) close() cb('ok') end)
RegisterNUICallback('cancel', function(_, cb) stopCraft(true) cb('ok') end)
RegisterNUICallback('craft', function(d, cb)
    if not crafting then TriggerServerEvent('og_crafting:start', d.idx, d.qty) end
    cb('ok')
end)

RegisterNetEvent('og_crafting:started', function(ms)
    crafting = true
    SendNUIMessage({ action = 'progress', ms = ms })
    local ped = PlayerPedId()
    RequestAnimDict('mini@repair')
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded('mini@repair') and GetGameTimer() < t do Wait(0) end
    TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 3.0, 3.0, -1, 49, 0, false, false, false)
    local start = GetEntityCoords(ped)
    local ends = GetGameTimer() + ms
    CreateThread(function()
        while crafting do
            if GetGameTimer() >= ends then
                crafting = false
                ClearPedTasks(ped)
                TriggerServerEvent('og_crafting:finish')
                return
            end
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > 3.0 then
                stopCraft(true)
                return
            end
            Wait(200)
        end
    end)
end)

RegisterNetEvent('og_crafting:done', function(r)
    SendNUIMessage({ action = 'done', result = r })
    if r.levelUp then
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    else
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    if open then TriggerServerEvent('og_crafting:open') end
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
