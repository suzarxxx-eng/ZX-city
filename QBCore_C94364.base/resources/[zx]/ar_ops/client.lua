local QBCore = exports['qb-core']:GetCoreObject()
local zones = {}

local function job()
    local pd = QBCore.Functions.GetPlayerData()
    return pd and pd.job
end
local function isMember() local j = job() return j and Config.Jobs[j.name] end
local function onDuty() local j = job() return j and Config.Jobs[j.name] and j.onduty end

local function ops() return GlobalState.arOps or {} end
local function myCid() local pd = QBCore.Functions.GetPlayerData() return pd and pd.citizenid end
local function holds(role)
    local s = ops()[role]
    return s and s.cid == myCid()
end
local function free(role)
    local s = ops()[role]
    return not s
end
local function holdsAny() return holds('chief') or holds('deputy') end

local function options()
    return {
        { icon = 'fas fa-right-to-bracket', label = 'تسجيل دخول',
          canInteract = function() return isMember() and not onDuty() end,
          action = function() TriggerServerEvent('ar_ops:server:duty', true) end },
        { icon = 'fas fa-satellite-dish', label = 'استلام مركز العمليات',
          canInteract = function() return onDuty() and free('chief') and not holdsAny() end,
          action = function() TriggerServerEvent('ar_ops:server:take', 'chief') end },
        { icon = 'fas fa-headset', label = 'استلام نائب مركز العمليات',
          canInteract = function() return onDuty() and free('deputy') and not holdsAny() end,
          action = function() TriggerServerEvent('ar_ops:server:take', 'deputy') end },
        { icon = 'fas fa-person-walking-arrow-right', label = 'ترك مركز العمليات',
          canInteract = function() return onDuty() and holds('chief') end,
          action = function() TriggerServerEvent('ar_ops:server:leave') end },
        { icon = 'fas fa-person-walking-arrow-right', label = 'ترك نيابة مركز العمليات',
          canInteract = function() return onDuty() and holds('deputy') end,
          action = function() TriggerServerEvent('ar_ops:server:leave') end },
        { icon = 'fas fa-right-from-bracket', label = 'تسجيل خروج',
          canInteract = function() return onDuty() end,
          action = function() TriggerServerEvent('ar_ops:server:duty', false) end },
    }
end

local function addDesk(name, d)
    local c = vector3(d.coords and d.coords.x or d.x, d.coords and d.coords.y or d.y, d.coords and d.coords.z or d.z)
    exports['qb-target']:AddBoxZone(name, c, d.length or 2.2, d.width or 1.4, {
        name = name, heading = d.heading or 0.0, debugPoly = false,
        minZ = c.z - 1.2, maxZ = c.z + 1.2,
    }, { options = options(), distance = Config.Distance })
    zones[#zones + 1] = name
end

local function build(extra)
    for _, n in ipairs(zones) do pcall(function() exports['qb-target']:RemoveZone(n) end) end
    zones = {}
    for i, d in ipairs(Config.Desks) do addDesk('ar_ops_desk_' .. i, d) end
    for i, d in ipairs(extra or {}) do addDesk('ar_ops_extra_' .. i, d) end
end

RegisterNetEvent('ar_ops:client:desks', function(extra) build(extra) end)

CreateThread(function()
    Wait(1500)
    build({})
    TriggerServerEvent('ar_ops:server:getDesks')
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for _, n in ipairs(zones) do pcall(function() exports['qb-target']:RemoveZone(n) end) end
end)
