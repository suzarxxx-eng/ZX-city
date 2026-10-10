-- طبقة توافقية: تعوّض ox_lib و mt_core على سيرفر QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- cache.ped / cache.vehicle / cache.serverId تُقرأ حيّاً عند كل استخدام
cache = setmetatable({}, {
    __index = function(_, k)
        if k == 'ped' then
            return PlayerPedId()
        elseif k == 'vehicle' then
            local v = GetVehiclePedIsIn(PlayerPedId(), false)
            return (v ~= 0) and v or nil
        elseif k == 'serverId' then
            return GetPlayerServerId(PlayerId())
        end
        return nil
    end,
})

local function enumVehicles()
    local list = {}
    local handle, veh = FindFirstVehicle()
    if not veh or veh == 0 then return list end
    repeat
        list[#list + 1] = veh
        veh = FindNextVehicle(handle)
    until not veh or veh == 0
    EndFindVehicle(handle)
    return list
end

lib = {
    print = {
        warn = function(msg) print(('[mt_radialmenu WARN] %s'):format(tostring(msg))) end,
        error = function(msg) print(('[mt_radialmenu ERROR] %s'):format(tostring(msg))) end,
    },
    disableControls = function() end, -- cl_main يعطّل الأزرار بنفسه
    getClosestPlayer = function(coords, maxDistance, includeSelf)
        local bestDist, bestId, bestPed, bestCoords = nil, nil, nil, nil
        for _, id in ipairs(GetActivePlayers()) do
            if includeSelf or id ~= PlayerId() then
                local ped = GetPlayerPed(id)
                local pc = GetEntityCoords(ped)
                local d = #(pc - coords)
                if d <= maxDistance and (not bestDist or d < bestDist) then
                    bestDist, bestId, bestPed, bestCoords = d, id, ped, pc
                end
            end
        end
        if bestId then return bestId, bestPed, bestCoords end
        return false
    end,
    getClosestVehicle = function(coords, maxDistance, includePlayerVehicle)
        local myVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        local bestDist, bestVeh = nil, nil
        for _, veh in ipairs(enumVehicles()) do
            if includePlayerVehicle or veh ~= myVeh then
                local d = #(GetEntityCoords(veh) - coords)
                if d <= maxDistance and (not bestDist or d < bestDist) then
                    bestDist, bestVeh = d, veh
                end
            end
        end
        if bestVeh then return bestVeh, bestDist end
        return false
    end,
}

function MTGetPlayerData()
    return QBCore.Functions.GetPlayerData()
end

function MTNotify(msg, kind)
    TriggerEvent('QBCore:Notify', msg, kind or 'primary')
end

function MTIsDead()
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand) then return true end
    return IsEntityDead(PlayerPedId())
end
