local anchor = nil
local spawned = {}      -- أغراض ومركبات المركز الموجودة حالياً
local built = false
local blip = nil

---------------------------------------------------------------- تحويل الإحداثيات النسبية لإحداثيات العالم
local function toWorld(lx, ly)
    local h = math.rad(anchor.h)
    local right = vector2(math.cos(h), math.sin(h))
    local fwd = vector2(-math.sin(h), math.cos(h))
    return anchor.x + right.x * lx + fwd.x * ly, anchor.y + right.y * lx + fwd.y * ly
end

local function groundZ(x, y)
    for _, offset in ipairs({ 5.0, 15.0, 40.0 }) do
        local found, z = GetGroundZFor_3dCoord(x, y, anchor.z + offset, false)
        if found then return z end
    end
    return anchor.z - 1.0
end

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(model)
end

---------------------------------------------------------------- البناء والإزالة
local function destroy()
    for _, e in ipairs(spawned) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    spawned = {}
    built = false
end

local function build()
    if built or not anchor then return end
    built = true
    -- نطلب كل الموديلات أول حتى تحميلها يصير سوة
    local missing = {}
    for _, e in ipairs(Layout) do
        local m = joaat(e.model)
        if not loadModel(m) then missing[e.model] = true end
    end

    for _, e in ipairs(Layout) do
        if not missing[e.model] then
            local x, y = toWorld(e.x, e.y)
            local z = groundZ(x, y) + (e.z or 0.0)
            local obj = CreateObjectNoOffset(joaat(e.model), x, y, z, false, false, false)
            SetEntityHeading(obj, (anchor.h + e.h) % 360.0)
            if not e.z then PlaceObjectOnGroundProperly(obj) end
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            spawned[#spawned + 1] = obj
        end
    end
    for model in pairs(missing) do
        print(('[ar_policemap] model not found, skipped: %s'):format(model))
    end

    if Config.ParkedCars then
        for _, c in ipairs(ParkedCars) do
            local m = joaat(c.model)
            if loadModel(m) then
                local x, y = toWorld(c.x, c.y)
                local veh = CreateVehicle(m, x, y, groundZ(x, y) + 0.5, (anchor.h + c.h) % 360.0, false, false)
                SetVehicleOnGroundProperly(veh)
                SetVehicleDoorsLocked(veh, 2)
                SetVehicleEngineOn(veh, false, true, true)
                FreezeEntityPosition(veh, true)
                SetEntityInvincible(veh, true)
                SetVehicleDirtLevel(veh, 0.0)
                spawned[#spawned + 1] = veh
                SetModelAsNoLongerNeeded(m)
            end
        end
    end

    for _, e in ipairs(Layout) do SetModelAsNoLongerNeeded(joaat(e.model)) end
end

local function updateBlip()
    if blip then RemoveBlip(blip) blip = nil end
    if not anchor or not Config.Blip.enabled then return end
    local x, y = toWorld(0.0, 14.0)
    blip = AddBlipForCoord(x, y, anchor.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------- مزامنة ويا السيرفر
RegisterNetEvent('ar_policemap:client:set', function(a)
    destroy()
    anchor = a
    updateBlip()
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('ar_policemap:server:request')
    while true do
        if anchor then
            local dist = #(GetEntityCoords(PlayerPedId()) - vector3(anchor.x, anchor.y, anchor.z))
            if dist < Config.SpawnDistance and not built then
                build()
            elseif dist > Config.SpawnDistance + 30.0 and built then
                destroy()
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    destroy()
    if blip then RemoveBlip(blip) end
end)
