local QBCore = exports['qb-core']:GetCoreObject()
local busy = false

local Anims = {
    work    = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 49 },
    inspect = { dict = 'amb@world_human_clipboard@male@idle_a', anim = 'idle_c', flag = 49 },
    read    = { dict = 'amb@world_human_clipboard@male@idle_a', anim = 'idle_c', flag = 49, prop = `p_amb_clipboard_01`, bone = 36029, pos = vector3(0.16, 0.08, 0.1), rot = vector3(-130.0, -50.0, 0.0) },
    drill   = { dict = 'anim@heists@fleeca_bank@drilling', anim = 'drill_straight_idle', flag = 49, prop = `hei_prop_heist_drill`, bone = 57005, pos = vector3(0.14, 0.0, -0.01), rot = vector3(90.0, -90.0, 180.0) },
    lighter = { dict = 'amb@world_human_smoking@male@male_a@enter', anim = 'enter', flag = 49, prop = `p_cs_lighter_01`, bone = 57005, pos = vector3(0.13, 0.02, 0.0), rot = vector3(-90.0, 0.0, 0.0) },
    eat     = { dict = 'mp_player_inteat@burger', anim = 'mp_player_int_eat_burger', flag = 49, prop = `prop_cs_burger_01`, bone = 18905, pos = vector3(0.13, 0.05, 0.02), rot = vector3(-50.0, 16.0, 60.0) },
    drink   = { dict = 'mp_player_intdrink', anim = 'loop_bottle', flag = 49, prop = `prop_ld_flow_bottle`, bone = 18905, pos = vector3(0.12, 0.008, 0.03), rot = vector3(240.0, -60.0, 0.0) },
    alcohol = { dict = 'mp_player_intdrink', anim = 'loop_bottle', flag = 49, prop = `prop_wine_rose`, bone = 18905, pos = vector3(0.12, 0.008, -0.1), rot = vector3(240.0, -60.0, 0.0) },
    refuel  = { dict = 'weapon@w_sp_jerrycan', anim = 'fire', flag = 49, prop = `w_am_jerrycan`, bone = 57005, pos = vector3(0.18, 0.13, -0.24), rot = vector3(-165.0, -11.0, -10.0) },
}

local function loadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(0) end
end

local function attach(a)
    if not a.prop then return end
    RequestModel(a.prop)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(a.prop) and GetGameTimer() < t do Wait(0) end
    local ped = PlayerPedId()
    local o = CreateObject(a.prop, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, a.bone), a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(a.prop)
    return o
end

-- شريط تقدم + حركة، وبالنهاية cb(true/false)
local function run(label, ms, kind, cb)
    if busy then return QBCore.Functions.Notify('أنت مشغول', 'error') end
    busy = true
    local a = Anims[kind] or Anims.inspect
    local ped = PlayerPedId()
    loadDict(a.dict)
    TaskPlayAnim(ped, a.dict, a.anim, 3.0, 3.0, -1, a.flag, 0, false, false, false)
    local prop = attach(a)
    QBCore.Functions.Progressbar('og_items_use', label, ms, false, true,
        { disableMovement = false, disableCarMovement = false, disableMouse = false, disableCombat = true }, {}, {}, {},
        function()
            busy = false
            StopAnimTask(ped, a.dict, a.anim, 1.0)
            if prop then DeleteEntity(prop) end
            cb(true)
        end,
        function()
            busy = false
            StopAnimTask(ped, a.dict, a.anim, 1.0)
            if prop then DeleteEntity(prop) end
            cb(false)
        end)
end

RegisterNetEvent('og_items:progress', function(label, ms, kind, data)
    run(label, ms, kind, function(ok)
        if not ok then
            TriggerServerEvent('og_items:cancel')
            return QBCore.Functions.Notify('انلغى', 'error')
        end
        if not data then return end
        if data.kind == 'msg' then QBCore.Functions.Notify(data.msg, 'primary', 6000)
        else TriggerServerEvent('og_items:done', data) end
    end)
end)

-- أكل وشرب
RegisterNetEvent('og_items:consume', function(kind, amount)
    local label = kind == 'eat' and 'تاكل...' or 'تشرب...'
    run(label, 5000, kind, function(ok)
        if not ok then return end
        local md = QBCore.Functions.GetPlayerData().metadata
        if kind == 'eat' then
            TriggerServerEvent('consumables:server:addHunger', math.min(100, (md.hunger or 0) + amount))
        else
            TriggerServerEvent('consumables:server:addThirst', math.min(100, (md.thirst or 0) + amount))
        end
        if kind == 'alcohol' then
            SetTimecycleModifier('spectator5')
            ShakeGameplayCam('DRUNK_SHAKE', 0.6)
            SetTimeout(20000, function() ClearTimecycleModifier() StopGameplayCamShaking(true) end)
        end
    end)
end)

-- تلفون
RegisterNetEvent('og_items:phone', function()
    if GetResourceState('qb-phone') == 'started' then ExecuteCommand('phone')
    else QBCore.Functions.Notify('ماكو سكربت موبايل شغال', 'error') end
end)

-- تابلت / لابتوب (تشغيل وإطفاء)
local tabletProp
RegisterNetEvent('og_items:tablet', function(kind)
    local ped = PlayerPedId()
    if tabletProp then
        DeleteEntity(tabletProp) tabletProp = nil
        StopAnimTask(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
        return
    end
    local model = kind == 'laptop' and `prop_laptop_01a` or `prop_cs_tablet`
    loadDict('amb@code_human_in_bus_passenger_idles@female@tablet@base')
    TaskPlayAnim(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
    tabletProp = attach({ prop = model, bone = 60309, pos = vector3(0.03, 0.002, -0.0), rot = vector3(10.0, 160.0, 0.0) })
    QBCore.Functions.Notify('استعمله مرة ثانية حتى تسده', 'primary')
end)

-- ساعة رياضية
RegisterNetEvent('og_items:fitbit', function()
    local ped = PlayerPedId()
    local md = QBCore.Functions.GetPlayerData().metadata
    local hp = math.max(0, GetEntityHealth(ped) - 100)
    QBCore.Functions.Notify(('الصحة %d%% | الدرع %d%% | الأكل %d%% | الماي %d%% | الضغط %d%%'):format(hp, GetPedArmour(ped), math.floor(md.hunger or 0), math.floor(md.thirst or 0), math.floor(md.stress or 0)), 'primary', 7000)
end)

-- جهاز تحديد موقع: يدز موقعك لأقرب لاعب
RegisterNetEvent('og_items:pinger', function()
    local p, d = QBCore.Functions.GetClosestPlayer()
    if p == -1 or d > 4.0 then return QBCore.Functions.Notify('ماكو أحد يمك', 'error') end
    TriggerServerEvent('og_items:ping', GetPlayerServerId(p))
end)

RegisterNetEvent('og_items:waypoint', function(x, y, msg)
    SetNewWaypoint(x + 0.0, y + 0.0)
    QBCore.Functions.Notify(msg, 'success', 6000)
end)

-- عكاز (تشغيل وإطفاء)
local cane
RegisterNetEvent('og_items:walkstick', function()
    local ped = PlayerPedId()
    if cane then
        DeleteEntity(cane) cane = nil
        ResetPedMovementClipset(ped, 0.5)
        return
    end
    RequestAnimSet('move_lester_CaneUp')
    local t = GetGameTimer() + 3000
    while not HasAnimSetLoaded('move_lester_CaneUp') and GetGameTimer() < t do Wait(0) end
    SetPedMovementClipset(ped, 'move_lester_CaneUp', 0.5)
    cane = attach({ prop = `prop_cs_walking_stick`, bone = 57005, pos = vector3(0.16, 0.06, 0.0), rot = vector3(335.0, 300.0, 120.0) })
end)

-- جليكان: يعبي أقرب سيارة
RegisterNetEvent('og_items:refuel', function()
    local ped = PlayerPedId()
    local veh = GetClosestVehicle(GetEntityCoords(ped), 4.0, 0, 71)
    if veh == 0 or IsPedInAnyVehicle(ped, false) then
        TriggerServerEvent('og_items:cancel')
        return QBCore.Functions.Notify('قرب على سيارة وانزل منها', 'error')
    end
    TaskTurnPedToFaceEntity(ped, veh, 1000)
    Wait(800)
    run('تعبي بانزين...', 8000, 'refuel', function(ok)
        if not ok then return TriggerServerEvent('og_items:cancel') end
        local cur = GetVehicleFuelLevel(veh)
        local new = math.min(100.0, cur + 25.0)
        if GetResourceState('qb-fuel') == 'started' then exports['qb-fuel']:SetFuel(veh, new) else SetVehicleFuelLevel(veh, new) end
        TriggerServerEvent('og_items:done', { kind = 'refuel' })
        QBCore.Functions.Notify('عبيت السيارة', 'success')
    end)
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if tabletProp then DeleteEntity(tabletProp) end
    if cane then DeleteEntity(cane) ResetPedMovementClipset(PlayerPedId(), 0.5) end
end)
