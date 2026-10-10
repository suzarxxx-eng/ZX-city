local QBCore = exports['qb-core']:GetCoreObject()
local KVP = 'ar_policemap:anchor'

local anchor = nil
do
    local raw = GetResourceKvpString(KVP)
    if raw and raw ~= '' then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' and t.x then anchor = t end
    end
end

local function broadcast(target)
    TriggerClientEvent('ar_policemap:client:set', target or -1, anchor)
end

-- /policemap : يبني المركز بمكانك الحالي (البوابة قدامك، والمركز يمتد لجهة وجهك)
QBCore.Commands.Add('policemap', 'بناء مركز الشرطة بمكانك الحالي', {}, false, function(source)
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    anchor = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    SetResourceKvp(KVP, json.encode(anchor))
    broadcast()
    TriggerClientEvent('QBCore:Notify', source, 'تم بناء مركز الشرطة هنا', 'success')
end, Config.Permission)

-- /policemapremove : يشيل المركز
QBCore.Commands.Add('policemapremove', 'إزالة مركز الشرطة', {}, false, function(source)
    anchor = nil
    DeleteResourceKvp(KVP)
    broadcast()
    TriggerClientEvent('QBCore:Notify', source, 'تم إزالة مركز الشرطة', 'success')
end, Config.Permission)

RegisterNetEvent('ar_policemap:server:request', function()
    broadcast(source)
end)
