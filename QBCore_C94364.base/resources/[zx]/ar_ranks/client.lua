local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open()
    if isOpen then return end
    local job = QBCore.Functions.GetPlayerData().job
    if not job or not Config.Jobs[job.name] then
        QBCore.Functions.Notify('هاي اللوحة بس للأمن العام', 'error')
        return
    end
    QBCore.Functions.TriggerCallback('ar_ranks:getData', function(data)
        if not data then return end
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = data })
    end)
end

RegisterCommand(Config.Command, open, false)
RegisterKeyMapping(Config.Command, 'لوحة رتب الأمن العام', 'keyboard', Config.Key)

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('action', function(act, cb)
    QBCore.Functions.TriggerCallback('ar_ranks:action', function(res)
        cb(res or { ok = false })
    end, act)
end)

-- ترقية / تنزيل / تعيين وصلت للاعب
RegisterNetEvent('ar_ranks:client:changed', function(d)
    SendNUIMessage({ action = 'changed', data = d, insignia = d.insignia })
    if d.up then
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    else
        PlaySoundFrontend(-1, 'LOSER', 'HUD_AWARDS', true)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
