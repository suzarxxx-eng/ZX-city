local QBCore = exports['qb-core']:GetCoreObject()
local Rented = {} -- [citizenid] = true

local function notify(src, msg, kind)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary')
end

local function nearPed(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end -- OneSync off: can't check, trust the client
    local p = Config.Ped.coords
    return #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) < 10.0
end

RegisterNetEvent('og_rental:server:rent', function(index)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    local veh = Config.Vehicles[tonumber(index) or 0]
    if not Player or not veh or not nearPed(src) then return end
    local cid = Player.PlayerData.citizenid
    if Rented[cid] then
        return notify(src, 'عندك مركبة مستأجرة، ارجعها أول', 'error')
    end
    local paid = false
    if (Player.GetMoney('cash') or 0) >= veh.price then
        paid = Player.RemoveMoney('cash', veh.price, 'vehicle-rental')
    elseif (Player.GetMoney('bank') or 0) >= veh.price then
        paid = Player.RemoveMoney('bank', veh.price, 'vehicle-rental')
    end
    if not paid then
        return notify(src, ('ما عندك فلوس كافية ($%d)'):format(veh.price), 'error')
    end
    Rented[cid] = true
    notify(src, ('استأجرت %s بـ $%d'):format(veh.label, veh.price), 'success')
    TriggerClientEvent('og_rental:client:spawn', src, tonumber(index))
end)

-- the client tells us the spawn failed (no free spot): refund
RegisterNetEvent('og_rental:server:spawnFailed', function(index)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    local veh = Config.Vehicles[tonumber(index) or 0]
    if not Player or not veh then return end
    local cid = Player.PlayerData.citizenid
    if not Rented[cid] then return end
    Rented[cid] = nil
    Player.AddMoney('cash', veh.price, 'vehicle-rental-refund')
    notify(src, 'ما لقيت مكان فاضي للمركبة، رجعت لك فلوسك', 'error')
end)

RegisterNetEvent('og_rental:server:returned', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    Rented[Player.PlayerData.citizenid] = nil
end)

AddEventHandler('playerDropped', function()
    -- the rented vehicle is a local entity of that client and disappears with them
    local Player = exports['qb-core']:GetPlayer(source)
    if Player then Rented[Player.PlayerData.citizenid] = nil end
end)
