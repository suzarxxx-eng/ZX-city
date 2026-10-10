-- nx_hud server: counts on-duty units per job and tells each on-duty player.
-- Players who are not in a configured job (or are off duty) receive nothing,
-- so civilians cost zero network traffic.

local Framework = Config.Framework
if Framework == 'auto' then
    if GetResourceState('qb-core') == 'started' then Framework = 'qb'
    elseif GetResourceState('es_extended') == 'started' then Framework = 'esx'
    else Framework = 'standalone' end
end

local QBCore, ESX
if Framework == 'qb' then QBCore = exports['qb-core']:GetCoreObject()
elseif Framework == 'esx' then ESX = exports['es_extended']:getSharedObject() end

-- Standalone: other scripts call exports['nx_hud']:SetPlayerJob(src, 'police', true)
local standalone = {}
exports('SetPlayerJob', function(src, job, onDuty)
    standalone[src] = { job = job, onduty = onDuty and true or false }
    TriggerEvent('nx_hud:refresh')
end)
AddEventHandler('playerDropped', function() standalone[source] = nil end)

-- Returns { {src=, job=, onduty=}, ... }
local function getPlayers()
    local out = {}
    if Framework == 'qb' then
        for src, p in pairs(QBCore.Functions.GetQBPlayers()) do
            local j = p.PlayerData.job
            out[#out + 1] = { src = src, job = j.name, onduty = j.onduty }
        end
    elseif Framework == 'esx' then
        local prefix = Config.ESXOffDutyPrefix
        for _, xp in pairs(ESX.GetExtendedPlayers()) do
            local name = xp.job.name
            local on = true
            if prefix and name:sub(1, #prefix) == prefix and Config.Jobs[name:sub(#prefix + 1)] then
                name, on = name:sub(#prefix + 1), false
            end
            out[#out + 1] = { src = xp.source, job = name, onduty = on }
        end
    else
        for src, d in pairs(standalone) do
            out[#out + 1] = { src = src, job = d.job, onduty = d.onduty }
        end
    end
    return out
end

local lastSent = {} -- src -> true if the player currently shows the badge

local function refresh()
    local counts = {}
    local players = getPlayers()
    for i = 1, #players do
        local p = players[i]
        if p.onduty and Config.Jobs[p.job] then
            counts[p.job] = (counts[p.job] or 0) + 1
        end
    end

    for i = 1, #players do
        local p = players[i]
        local cfg = Config.Jobs[p.job]
        if p.onduty and cfg then
            TriggerClientEvent('nx_hud:job', p.src,
                { show = true, label = cfg.label, icon = cfg.icon, count = counts[p.job] })
            lastSent[p.src] = true
        elseif lastSent[p.src] then
            TriggerClientEvent('nx_hud:job', p.src, { show = false })
            lastSent[p.src] = nil
        end
    end
end

-- Debounced so a burst of job changes causes one recount
local pending = false
local function queueRefresh()
    if pending then return end
    pending = true
    SetTimeout(500, function() pending = false; refresh() end)
end

AddEventHandler('nx_hud:refresh', queueRefresh)
AddEventHandler('playerDropped', function() lastSent[source] = nil; queueRefresh() end)

-- Framework hooks: instant update on job/duty change
if Framework == 'qb' then
    AddEventHandler('QBCore:Server:OnJobUpdate', queueRefresh)
    AddEventHandler('QBCore:Server:PlayerLoaded', queueRefresh)
    RegisterNetEvent('QBCore:ToggleDuty', queueRefresh)
elseif Framework == 'esx' then
    AddEventHandler('esx:setJob', queueRefresh)
    AddEventHandler('esx:playerLoaded', queueRefresh)
end

CreateThread(function()
    Wait(3000)
    while true do
        refresh()
        Wait(Config.JobRefresh)
    end
end)
