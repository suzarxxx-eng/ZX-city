-- ============================================================
--  mt_radialmenu — server/main.lua
--  Server side event handling and player data query callbacks
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('mt_radialmenu:server:hasPermission', function(source, cb, permName)
    local src = source
    if not permName then return cb(false) end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    
    cb(QBCore.Functions.HasPermission(src, permName) or false)
end)

RegisterNetEvent('mt_radialmenu:server:triggerAction', function(actionName, data)
    local src = source
    if not actionName then return end
    TriggerEvent('mt_radialmenu:server:onActionExecuted', src, actionName, data)
end)

RegisterNetEvent('mt_radialmenu:server:giveCash', function(targetId, amount)
    local src = source
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or targetId == src or amount <= 0 or amount > 100000 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Player or not Target then return end

    local srcPed, tgtPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if srcPed == 0 or tgtPed == 0 then return end
    if #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed)) > 3.0 then return end

    if not Player.Functions.RemoveMoney('cash', amount, 'gave-cash') then
        TriggerClientEvent('QBCore:Notify', src, 'ما عندك كاش كافي', 'error')
        return
    end
    Target.Functions.AddMoney('cash', amount, 'received-cash')
    TriggerClientEvent('QBCore:Notify', src, 'أعطيت $' .. amount, 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'استلمت $' .. amount, 'success')
end)
