local QBCore = exports['qb-core']:GetCoreObject()
local rentalPed
local rentedVehicle

local function setFuel(veh)
    for _, res in ipairs({ 'qb-fuel', 'LegacyFuel' }) do
        if GetResourceState(res) == 'started' then
            if pcall(function() exports[res]:SetFuel(veh, 100.0) end) then return end
        end
    end
    Entity(veh).state.fuel = 100.0
end

local function openMenu()
    local menu = { { header = 'تأجير المركبات', isMenuHeader = true } }
    for i, v in ipairs(Config.Vehicles) do
        menu[#menu + 1] = {
            header = v.label,
            txt = ('السعر: $%d'):format(v.price),
            icon = v.icon,
            params = { isServer = true, event = 'og_rental:server:rent', args = i },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

local function returnVehicle()
    if not rentedVehicle or not DoesEntityExist(rentedVehicle) then
        rentedVehicle = nil
        TriggerServerEvent('og_rental:server:returned')
        return QBCore.Functions.Notify('ماكو مركبة مستأجرة عندك', 'error')
    end
    local p = Config.Ped.coords
    if #(GetEntityCoords(rentedVehicle) - vector3(p.x, p.y, p.z)) > 25.0 then
        return QBCore.Functions.Notify('جيب المركبة قرب الموظف', 'error')
    end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == rentedVehicle then TaskLeaveVehicle(ped, rentedVehicle, 0) Wait(1500) end
    DeleteEntity(rentedVehicle)
    rentedVehicle = nil
    TriggerServerEvent('og_rental:server:returned')
    QBCore.Functions.Notify('تم ارجاع المركبة', 'success')
end

local function freeSpawnPoint()
    for _, sp in ipairs(Config.SpawnPoints) do
        if not IsAnyVehicleNearPoint(sp.x, sp.y, sp.z, 2.5) then return sp end
    end
end

RegisterNetEvent('og_rental:client:spawn', function(index)
    local v = Config.Vehicles[index]
    local sp = freeSpawnPoint()
    if not v or not sp then return TriggerServerEvent('og_rental:server:spawnFailed', index) end
    local model = joaat(v.model)
    if not IsModelInCdimage(model) then return TriggerServerEvent('og_rental:server:spawnFailed', index) end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then return TriggerServerEvent('og_rental:server:spawnFailed', index) end

    local veh = CreateVehicle(model, sp.x, sp.y, sp.z, sp.w, true, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'RENT' .. math.random(1000, 9999))
    setFuel(veh)
    SetVehicleDirtLevel(veh, 0.0)
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
    rentedVehicle = veh
    QBCore.Functions.Notify('مركبتك جاهزة', 'success')
end)

CreateThread(function()
    local c = Config.Ped.coords
    local model = joaat(Config.Ped.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    rentalPed = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(rentalPed, true)
    SetBlockingOfNonTemporaryEvents(rentalPed, true)
    FreezeEntityPosition(rentalPed, true)
    if Config.Ped.scenario then TaskStartScenarioInPlace(rentalPed, Config.Ped.scenario, 0, true) end
    SetModelAsNoLongerNeeded(model)

    exports['qb-target']:AddTargetEntity(rentalPed, {
        options = {
            { action = openMenu, icon = 'fas fa-car', label = 'تأجير مركبة' },
            { action = returnVehicle, icon = 'fas fa-rotate-left', label = 'ارجاع المركبة المستأجرة' },
        },
        distance = 2.5,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if rentalPed and DoesEntityExist(rentalPed) then
        exports['qb-target']:RemoveTargetEntity(rentalPed)
        DeleteEntity(rentalPed)
    end
    if rentedVehicle and DoesEntityExist(rentedVehicle) then DeleteEntity(rentedVehicle) end
end)
