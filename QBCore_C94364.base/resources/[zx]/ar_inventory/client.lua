local isOpen   = false
local slotList = {}
local weight   = 0.0
local drops    = {}
local nearId   = nil

---------------------------------------------------------------- NUI
local function pushState()
    SendNUIMessage({
        action = 'init',
        items = Config.Items, slots = Config.Slots, hotbar = Config.HotbarSlots,
        maxWeight = Config.MaxWeight,
    })
    SendNUIMessage({ action = 'sync', slots = slotList, weight = weight })
end

local function openInv()
    if isOpen or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    CreateThread(function()
        while isOpen do
            Wait(500)
            if IsEntityDead(PlayerPedId()) then
                isOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
            end
        end
    end)
end

local function closeInv()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('ready', function(_, cb) pushState() cb('ok') end)
RegisterNUICallback('close', function(_, cb) closeInv() cb('ok') end)
RegisterNUICallback('move', function(d, cb) TriggerServerEvent('ar_inventory:move', d.from, d.to, d.amount) cb('ok') end)
RegisterNUICallback('use',  function(d, cb) TriggerServerEvent('ar_inventory:use', d.slot) cb('ok') end)
RegisterNUICallback('drop', function(d, cb) TriggerServerEvent('ar_inventory:drop', d.slot, d.amount) cb('ok') end)
RegisterNUICallback('give', function(d, cb)
    local me = PlayerPedId()
    local myCoords = GetEntityCoords(me)
    local best, bestDist
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= me then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist <= Config.GiveDistance and (not bestDist or dist < bestDist) then
                best, bestDist = GetPlayerServerId(pl), dist
            end
        end
    end
    if best then
        TriggerServerEvent('ar_inventory:give', d.slot, d.amount, best)
    else
        SendNUIMessage({ action = 'toast', text = 'لا يوجد لاعب قريب منك', kind = 'error' })
    end
    cb('ok')
end)

---------------------------------------------------------------- أحداث من السيرفر
RegisterNetEvent('ar_inventory:sync', function(list, w)
    slotList, weight = list, w
    SendNUIMessage({ action = 'sync', slots = list, weight = w })
end)

RegisterNetEvent('ar_inventory:notify', function(text, kind)
    SendNUIMessage({ action = 'toast', text = text, kind = kind })
end)

RegisterNetEvent('ar_inventory:dropsSync', function(t) drops = t or {} end)
RegisterNetEvent('ar_inventory:dropAdd', function(id, d) drops[id] = d end)
RegisterNetEvent('ar_inventory:dropRemove', function(id) drops[id] = nil end)

local function playAnim(a)
    CreateThread(function()
        local ped = PlayerPedId()
        RequestAnimDict(a.dict)
        local timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(a.dict) and GetGameTimer() < timeout do Wait(10) end
        if HasAnimDictLoaded(a.dict) then
            TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, a.time or 2500, 49, 0.0, false, false, false)
        end
    end)
end

RegisterNetEvent('ar_inventory:client:use', function(name)
    local d = Config.Items[name]
    if not d then return end
    local ped = PlayerPedId()
    local e = d.effect
    if e then
        if e.health then
            SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + e.health))
        end
        if e.armor then
            SetPedArmour(ped, math.min(100, GetPedArmour(ped) + e.armor))
        end
    end
    if d.anim then playAnim(d.anim) end
    SendNUIMessage({ action = 'toast', text = 'تم استخدام ' .. d.label, kind = 'success' })
end)

---------------------------------------------------------------- مفاتيح
RegisterCommand('ar_inventory_toggle', function()
    if isOpen then closeInv() else openInv() end
end, false)
RegisterKeyMapping('ar_inventory_toggle', 'فتح / إغلاق الحقيبة', 'keyboard', Config.OpenKey)

for i = 1, Config.HotbarSlots do
    RegisterCommand('ar_hotbar' .. i, function()
        if isOpen or IsPauseMenuActive() then return end
        TriggerServerEvent('ar_inventory:use', Config.Slots + i)
        SendNUIMessage({ action = 'flash', slot = Config.Slots + i })
    end, false)
    RegisterKeyMapping('ar_hotbar' .. i, ('خانة الاستخدام السريع %d'):format(i), 'keyboard', tostring(i))
end

-- منع اختيار الأسلحة بالأرقام 1-5 وعجلة الأسلحة
CreateThread(function()
    local blocked = { 157, 158, 160, 164, 165, 37 }
    while true do
        for _, c in ipairs(blocked) do DisableControlAction(0, c, true) end
        Wait(0)
    end
end)

---------------------------------------------------------------- الأغراض المرمية
CreateThread(function()
    while true do
        local sleep = 700
        local pc = GetEntityCoords(PlayerPedId())
        local closest, closestDist

        for id, dr in pairs(drops) do
            local pos = vector3(dr.x, dr.y, dr.z)
            local dist = #(pc - pos)
            if dist < 15.0 then
                sleep = 0
                DrawMarker(2, dr.x, dr.y, dr.z + 0.3, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                    0.22, 0.22, 0.22, 46, 139, 255, 210, false, true, 2, false, nil, nil, false)
                if dist < Config.PickupDistance and (not closestDist or dist < closestDist) then
                    closest, closestDist = id, dist
                end
            end
        end

        if closest ~= nearId then
            nearId = closest
            if closest and not isOpen then
                local dr = drops[closest]
                local d = Config.Items[dr.name]
                SendNUIMessage({
                    action = 'prompt', show = true,
                    text = ('%s x%d'):format(d and d.label or dr.name, dr.count),
                })
            else
                SendNUIMessage({ action = 'prompt', show = false })
            end
        end

        if nearId and not isOpen and IsControlJustReleased(0, 38) then
            TriggerServerEvent('ar_inventory:pickup', nearId)
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------- بدء
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    TriggerServerEvent('ar_inventory:load')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

exports('IsOpen', function() return isOpen end)
exports('Close', closeInv)
