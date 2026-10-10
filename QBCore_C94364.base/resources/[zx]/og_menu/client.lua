local QBCore = exports['qb-core']:GetCoreObject()
local open = false
local loaded = false

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() loaded = true end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() loaded = false end)
AddEventHandler('onResourceStart', function(r)
    if r == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then loaded = true end
end)

local function fetch(cb)
    QBCore.Functions.TriggerCallback('og_menu:data', function(raw)
        if raw then cb(raw) end
    end)
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(400)
end

local function openMenu()
    if open then return end
    fetch(function(raw)
        open = true
        SetNuiFocus(true, true)
        TriggerScreenblurFadeIn(400)
        SendNUIMessage({ action = 'open', data = raw })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end)
end

-- ESC يفتح قائمة OG بدل قائمة اللعبة (P يبقى يفتح قائمة اللعبة العادية)
CreateThread(function()
    while true do
        if loaded and not open then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 200) and not IsPauseMenuActive() and not IsNuiFocused() then
                openMenu()
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('og_menu:refresh', function()
    if open then fetch(function(raw) SendNUIMessage({ action = 'update', data = raw }) end) end
end)

-- أزرار الواجهة
RegisterNUICallback('close', function(_, cb) close() cb('ok') end)

RegisterNUICallback('map', function(_, cb)
    close()
    CreateThread(function()
        Wait(150)
        ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1)
    end)
    cb('ok')
end)

RegisterNUICallback('settings', function(_, cb)
    close()
    CreateThread(function()
        Wait(150)
        ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1)
    end)
    cb('ok')
end)

RegisterNUICallback('arena', function(d, cb)
    close()
    if d and d.mode then TriggerServerEvent('og_arena:join', d.mode) end
    cb('ok')
end)

RegisterNUICallback('arenaLeave', function(_, cb)
    close()
    TriggerServerEvent('og_arena:leave')
    cb('ok')
end)

-- ===== تيد ام =====
RegisterNUICallback('tdmList', function(_, cb)
    QBCore.Functions.TriggerCallback('og_tdm:list', function(raw) cb(raw or 'null') end)
end)
RegisterNUICallback('tdmCreate', function(d, cb) TriggerServerEvent('og_tdm:create', d) cb('ok') end)
RegisterNUICallback('tdmJoin', function(d, cb) TriggerServerEvent('og_tdm:join', d.id, d.code) cb('ok') end)
RegisterNUICallback('tdmLeave', function(_, cb) TriggerServerEvent('og_tdm:leave') cb('ok') end)
RegisterNUICallback('tdmTeam', function(d, cb) TriggerServerEvent('og_tdm:team', d.team) cb('ok') end)
RegisterNUICallback('tdmVote', function(d, cb) TriggerServerEvent('og_tdm:vote', d.weapon) cb('ok') end)
RegisterNUICallback('tdmBalance', function(_, cb) TriggerServerEvent('og_tdm:balance') cb('ok') end)
RegisterNUICallback('tdmStart', function(_, cb) TriggerServerEvent('og_tdm:start') cb('ok') end)

RegisterNetEvent('og_tdm:room', function(v)
    SendNUIMessage({ action = 'room', room = v, me = GetPlayerServerId(PlayerId()) })
end)

AddEventHandler('og_menu:forceClose', function() close() end)

RegisterNUICallback('quit', function(_, cb)
    cb('ok')
    TriggerServerEvent('og_menu:quit')
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
        TriggerScreenblurFadeOut(0)
    end
end)
