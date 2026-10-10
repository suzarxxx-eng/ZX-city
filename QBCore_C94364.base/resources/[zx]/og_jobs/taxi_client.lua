-- التكسي بين اللاعبين (جانب العميل):
--   الزبون: /taxi [vip] يطلب (يلتقط وجهتك من علامة GPS إذا حاطها)، /taxicancel يلغي
--   السائق: التابلت (F6) يعرض طلبات اللاعبين، وبعد القبول تنحط علامة الزبون على الخريطة. /taxiend ينهي المشوار
local QBCore = exports['qb-core']:GetCoreObject()

local TAXI = 'taxi'
local taxiVeh
local trackBlip, trackKind
local tabletOpen = false

local function notify(msg, kind) OG.notify(msg, kind) end

local function clearTrack()
    if trackBlip then OG.removeBlip(trackBlip) end
    trackBlip, trackKind = nil, nil
end

local function hideMeter()
    SendNUIMessage({ action = 'meter', show = false })
end

---------------------------------------------------------------- متابعة الطرف الثاني + العداد
-- السيرفر يرسل مكان الطرف الثاني كل كم ثانية: السائق يشوف الزبون، والزبون يشوف التكسي
RegisterNetEvent('og_jobs:client:taxiTrack', function(kind, x, y, z)
    if kind == 'clear' then return clearTrack() end
    if trackBlip and trackKind == kind then
        SetBlipCoords(trackBlip, x, y, z)
        return
    end
    clearTrack()
    local toCustomer = kind == 'customer'
    trackBlip = OG.addBlip({
        coords = vector3(x, y, z), sprite = toCustomer and 280 or 198, color = 5, scale = 0.9,
        label = toCustomer and 'الزبون' or 'التكسي', shortRange = false,
    })
    trackKind = kind
    if toCustomer and trackBlip then
        SetBlipRoute(trackBlip, true)
        SetBlipRouteColour(trackBlip, 5)
    end
end)

RegisterNetEvent('og_jobs:client:taxiClear', function()
    clearTrack()
    hideMeter()
end)

RegisterNetEvent('og_jobs:client:taxiMeter', function(d)
    SendNUIMessage({ action = 'meter', show = d.show, fare = d.fare, dist = d.dist })
end)

RegisterNetEvent('og_jobs:client:taxiDest', function(x, y)
    SetNewWaypoint(x, y)
    notify('وجهة الزبون انحطت على الخريطة')
end)

RegisterNetEvent('og_jobs:client:taxiAssigned', function(driverName)
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
    notify(('السائق %s جاي لك. أول ما توصل السيارة اركب'):format(driverName), 'success')
end)

RegisterNetEvent('og_jobs:client:taxiRequest', function(info)
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    notify(('طلب تكسي جديد%s من %s%s • افتح التابلت (F6)'):format(
        info.vip and ' (VIP)' or '', info.name or '—', info.dist and (' • يبعد ' .. info.dist .. ' م') or ''))
end)

---------------------------------------------------------------- الزبون
RegisterCommand('taxi', function(_, args)
    local first = args[1] and args[1]:lower()
    local vip = first == 'vip' or first == 'فاخر'
    local dest
    local wp = GetFirstBlipInfoId(8) -- علامة GPS اللي حطيتها بالخريطة
    if DoesBlipExist(wp) then
        local c = GetBlipInfoIdCoord(wp)
        dest = { x = c.x, y = c.y }
    end
    TriggerServerEvent('og_jobs:server:taxiCall', vip, dest)
end, false)

RegisterCommand('taxicancel', function() TriggerServerEvent('og_jobs:server:taxiCancel') end, false)
RegisterCommand('taxiend', function() TriggerServerEvent('og_jobs:server:taxiEnd') end, false)

CreateThread(function()
    Wait(2500)
    TriggerEvent('chat:addSuggestion', '/taxi', 'اطلب تكسي من سائق لاعب (حدد وجهتك بالخريطة أول). اكتب /taxi vip لسيارة فاخرة', {})
    TriggerEvent('chat:addSuggestion', '/taxicancel', 'الغاء طلب التكسي أو المشوار', {})
    TriggerEvent('chat:addSuggestion', '/taxiend', 'للسائق: إنهاء المشوار ومحاسبة الزبون', {})
end)

---------------------------------------------------------------- سيارة الشركة (السائق)
local function spawnTaxi(idx)
    local j = Config.Jobs[TAXI]
    local v = j.vehicles[idx or 1]
    if taxiVeh and DoesEntityExist(taxiVeh) then return notify('عندك سيارة تكسي من قبل، ارجعها أول', 'error') end
    local hash = v and OG.loadModel(v.model)
    if not hash then return notify('ما كدرت أجيب السيارة', 'error') end
    local s = j.spawn
    if IsAnyVehicleNearPoint(s.x, s.y, s.z, 3.0) then return notify('مكان السيارة مشغول، انتظر شوي', 'error') end
    taxiVeh = CreateVehicle(hash, s.x, s.y, s.z, s.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleNumberPlateText(taxiVeh, 'TAXI' .. math.random(1000, 9999))
    SetVehicleOnGroundProperly(taxiVeh)
    for _, res in ipairs({ 'qb-fuel', 'LegacyFuel' }) do
        if GetResourceState(res) == 'started' then
            if pcall(function() exports[res]:SetFuel(taxiVeh, 100.0) end) then break end
        end
    end
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(taxiVeh))
    notify('استلمت سيارة التكسي', 'success')
end

local function returnTaxi()
    clearTrack()
    hideMeter()
    TriggerServerEvent('og_jobs:server:taxiReturned')
    if taxiVeh and DoesEntityExist(taxiVeh) then
        local ped = PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == taxiVeh then TaskLeaveVehicle(ped, taxiVeh, 0) Wait(1500) end
        DeleteEntity(taxiVeh)
        notify('رجعت السيارة', 'success')
    end
    taxiVeh = nil
end

RegisterNetEvent('og_jobs:client:taxiVehicle', function(idx)
    spawnTaxi(idx)
end)

---------------------------------------------------------------- التابلت
local function openTablet()
    if OG.employed() ~= TAXI then
        return notify('التابلت للموظفين بالتكسي بس. قدّم على الوظيفة من مركز التوظيف', 'error')
    end
    QBCore.Functions.TriggerCallback('og_jobs:cb:taxiData', function(data)
        if not data then return end
        tabletOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = data })
    end, TAXI)
end

RegisterNUICallback('close', function(_, cb)
    tabletOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- التابلت يحدّث الطلبات كل كم ثانية وهو مفتوح
RegisterNUICallback('taxiRefresh', function(_, cb)
    QBCore.Functions.TriggerCallback('og_jobs:cb:taxiData', function(data) cb(data or {}) end, TAXI)
end)

RegisterNUICallback('accept', function(data, cb)
    TriggerServerEvent('og_jobs:server:taxiAccept', data and data.id)
    cb('ok')
end)

RegisterNUICallback('vehicle', function(data, cb)
    TriggerServerEvent('og_jobs:server:taxiVehicle', TAXI, data and data.id)
    cb('ok')
end)

RegisterNUICallback('endRide', function(_, cb)
    TriggerServerEvent('og_jobs:server:taxiEnd')
    cb('ok')
end)

RegisterNUICallback('cancelRide', function(_, cb)
    TriggerServerEvent('og_jobs:server:taxiCancel')
    cb('ok')
end)

RegisterCommand('taxitablet', function() openTablet() end, false)
RegisterKeyMapping('taxitablet', 'فتح تابلت التكسي', 'keyboard', 'F6')

---------------------------------------------------------------- ربط مع client.lua
OG.openTablet = openTablet
OG.returnTaxi = returnTaxi
OG.taxiReset = function() -- لمن تتغيّر حالة دوامك: نشيل أيقونات المتابعة والعداد
    clearTrack()
    hideMeter()
end
OG.taxiCleanup = function()
    clearTrack()
    hideMeter()
    if tabletOpen then SetNuiFocus(false, false) end
    if taxiVeh and DoesEntityExist(taxiVeh) then DeleteEntity(taxiVeh) end
end
