-- Framework bridge: ESX / QBCore. Server functions are only defined on the server.
local fw = Config.Framework
if fw == 'auto' then
    if GetResourceState('qb-core') ~= 'missing' then
        fw = 'qb'
    elseif GetResourceState('es_extended') ~= 'missing' then
        fw = 'esx'
    end
end

Bridge = { framework = fw }

if not IsDuplicityVersion() then return end

local QBCore, ESX
if fw == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif fw == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

function Bridge.GetPlayer(src)
    if fw == 'qb' then return QBCore.Functions.GetPlayer(src) end
    if fw == 'esx' then return ESX.GetPlayerFromId(src) end
end

function Bridge.CountPolice()
    local n = 0
    if fw == 'qb' then
        for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
            local job = p.PlayerData.job
            if Config.Police.jobs[job.name] and job.onduty then n = n + 1 end
        end
    elseif fw == 'esx' then
        for _, p in pairs(ESX.GetExtendedPlayers()) do
            if Config.Police.jobs[p.job.name] then n = n + 1 end
        end
    end
    return n
end

function Bridge.HasItem(src, item)
    if fw == 'qb' then return exports['qb-inventory']:HasItem(src, item, 1) end
    if fw == 'esx' then
        local p = ESX.GetPlayerFromId(src)
        return p and p.getInventoryItem(item).count > 0
    end
end

function Bridge.RemoveItem(src, item, count)
    if fw == 'qb' then return exports['qb-inventory']:RemoveItem(src, item, count, false, 'og_robberies') end
    if fw == 'esx' then ESX.GetPlayerFromId(src).removeInventoryItem(item, count) end
end

function Bridge.ItemExists(item)
    if fw == 'qb' then return QBCore.Shared.Items[item] ~= nil end
    return true
end

function Bridge.AddItem(src, item, count)
    if not Bridge.ItemExists(item) then return false end
    if fw == 'qb' then return exports['qb-inventory']:AddItem(src, item, count, false, false, 'og_robberies') end
    if fw == 'esx' then ESX.GetPlayerFromId(src).addInventoryItem(item, count) return true end
end

function Bridge.AddCash(src, amount)
    if fw == 'qb' then
        local p = QBCore.Functions.GetPlayer(src)
        if p then p.Functions.AddMoney('cash', amount, 'og_robberies') end
    elseif fw == 'esx' then
        ESX.GetPlayerFromId(src).addMoney(amount)
    end
end

function Bridge.IsAdmin(src)
    if fw == 'qb' then return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') end
    if fw == 'esx' then local p = ESX.GetPlayerFromId(src) return p and p.getGroup() == 'admin' end
    return IsPlayerAceAllowed(src, 'command')
end
