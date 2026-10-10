Config = Config or {}
Config.Menu = Config.Menu or {}
Config.SubMenus = Config.SubMenus or {}

-- الوظائف اللي تشوف قائمة "الامن العام" وقنوات الراديو 1-5
Config.PoliceJobs = { police = true }
-- الوظائف اللي تشوف قائمة "الإسعاف" وقنوات الراديو 6-10
Config.EMSJobs = { ambulance = true }

-- ============================================================
-- دوال مساعدة
-- ============================================================

local function isDead(source)
    source = source or (cache and cache.serverId)
    if not source then return false end
    local ped = cache and cache.ped or PlayerPedId()
    if IsEntityDead(ped) then return true end
    local pData = MTGetPlayerData()
    if pData and pData.metadata then
        return pData.metadata.isdead or pData.metadata.inlaststand or false
    end
    return false
end

local function getJob()
    local pData = MTGetPlayerData()
    return pData and pData.job or nil
end

local function isPolice()
    local job = getJob()
    return job ~= nil and Config.PoliceJobs[job.name] == true
end

local function isEMS()
    local job = getJob()
    return job ~= nil and Config.EMSJobs[job.name] == true
end

-- يستخدمها cl_main حتى يطلع اللاعب من الراديو إذا تغيرت وظيفته
MTIsPolice, MTIsEMS = isPolice, isEMS

local function getClosestPlayer(maxDistance)
    local coords = GetEntityCoords(cache.ped or PlayerPedId())
    local playerId, playerPed, playerCoords = lib.getClosestPlayer(coords, maxDistance, false)
    if playerId and playerPed then
        return playerId, #(playerCoords - coords), playerPed
    end
    return false
end

local function getClosestVehicle(maxDistance, includePlayerVehicle)
    local coords = GetEntityCoords(cache.ped or PlayerPedId())
    local vehicle, distance = lib.getClosestVehicle(coords, maxDistance, includePlayerVehicle or false)
    if vehicle then return vehicle, distance end
    return false
end

-- تبديل باب سيارة (فتح/غلق)
local function toggleDoor(door)
    local v = cache.vehicle
    if not v then return end
    if GetVehicleDoorAngleRatio(v, door) > 0.0 then
        SetVehicleDoorShut(v, door, false)
    else
        SetVehicleDoorOpen(v, door, false, false)
    end
end

-- ============================================================
-- تحكم السيارة: المحرك / الزنون / النوافذ / المقاعد
-- ============================================================

local function toggleEngine()
    local v = cache.vehicle
    if not v then return end
    if GetPedInVehicleSeat(v, -1) ~= PlayerPedId() then
        MTNotify('لازم تكون السايق', 'error')
        return
    end
    local on = not GetIsVehicleEngineRunning(v)
    SetVehicleEngineOn(v, on, false, true)
    SetVehicleUndriveable(v, not on)
    MTNotify(on and 'شغلت المحرك' or 'طفيت المحرك', 'primary')
end

local function toggleXenon()
    local v = cache.vehicle
    if not v then return end
    if GetPedInVehicleSeat(v, -1) ~= PlayerPedId() then
        MTNotify('لازم تكون السايق', 'error')
        return
    end
    SetVehicleModKit(v, 0)
    local on = not IsToggleModOn(v, 22)
    ToggleVehicleMod(v, 22, on)
    if on then SetVehicleLights(v, 2) else SetVehicleLights(v, 0) end
    MTNotify(on and 'شغلت الزنون' or 'طفيت الزنون', 'primary')
end

-- حالة النوافذ لكل سيارة (اللعبة ما تعطي حالة النافذة النازلة)
local windowsDown = {}
local function toggleWindows(list, label)
    local v = cache.vehicle
    if not v then return end
    windowsDown[v] = windowsDown[v] or {}
    local state = windowsDown[v]
    local down = not state[list[1]]
    for _, w in ipairs(list) do
        if down then RollDownWindow(v, w) else RollUpWindow(v, w) end
        state[w] = down
    end
    MTNotify((down and 'نزلت ' or 'صعدت ') .. label, 'primary')
end

-- المقاعد: -1 السايق، 0 جنب السايق، 1 خلف اليسار، 2 خلف اليمين
local function switchSeat(seat, label)
    local v = cache.vehicle
    if not v then return end
    if GetEntitySpeed(v) * 3.6 > 5.0 then
        MTNotify('وكف السيارة أول', 'error')
        return
    end
    if seat > GetVehicleMaxNumberOfPassengers(v) - 1 then
        MTNotify('ماكو هذا المقعد بهاي السيارة', 'error')
        return
    end
    if not IsVehicleSeatFree(v, seat) then
        MTNotify('المقعد مو فارغ', 'error')
        return
    end
    SetPedIntoVehicle(PlayerPedId(), v, seat)
    MTNotify('انتقلت لـ ' .. label, 'primary')
end

-- ============================================================
-- نزع / لبس قطع الملابس (تحفظ القطعة قبل النزع لترجعها)
-- ============================================================

local clothingMemory = {}

local function toggleComponent(key, label, component, offDrawable)
    local ped = PlayerPedId()
    if clothingMemory[key] then
        local m = clothingMemory[key]
        SetPedComponentVariation(ped, component, m.d, m.t, m.p or 0)
        clothingMemory[key] = nil
        MTNotify('لبست ' .. label, 'primary')
    else
        clothingMemory[key] = {
            d = GetPedDrawableVariation(ped, component),
            t = GetPedTextureVariation(ped, component),
            p = GetPedPaletteVariation(ped, component),
        }
        SetPedComponentVariation(ped, component, offDrawable, 0, 0)
        MTNotify('نزعت ' .. label, 'primary')
    end
end

local function toggleProps(key, label, props)
    local ped = PlayerPedId()
    if clothingMemory[key] then
        for _, pr in ipairs(clothingMemory[key]) do
            SetPedPropIndex(ped, pr.id, pr.d, pr.t, true)
        end
        clothingMemory[key] = nil
        MTNotify('لبست ' .. label, 'primary')
    else
        local stored = {}
        for _, id in ipairs(props) do
            local d = GetPedPropIndex(ped, id)
            if d and d >= 0 then
                stored[#stored + 1] = { id = id, d = d, t = GetPedPropTextureIndex(ped, id) }
            end
        end
        if #stored == 0 then
            MTNotify('ماكو ' .. label, 'error')
            return
        end
        for _, id in ipairs(props) do ClearPedProp(ped, id) end
        clothingMemory[key] = stored
        MTNotify('نزعت ' .. label, 'primary')
    end
end

-- اعطاء كاش لأقرب لاعب عبر إدخال المبلغ
local function giveCash()
    local playerId = getClosestPlayer(2.5)
    if not playerId then
        MTNotify('ماكو لاعب قريب', 'error')
        return
    end
    local dialog = exports['qb-input']:ShowInput({
        header = 'اعطاء كاش',
        submitText = 'اعطاء',
        inputs = {
            { type = 'number', isRequired = true, name = 'amount', text = 'المبلغ' },
        },
    })
    if not dialog or not dialog.amount then return end
    local amount = math.floor(tonumber(dialog.amount) or 0)
    if amount <= 0 then
        MTNotify('مبلغ غير صحيح', 'error')
        return
    end
    TriggerServerEvent('mt_radialmenu:server:giveCash', playerId, amount)
end

-- ============================================================
-- القائمة الرئيسية
-- ============================================================

Config.Menu = {
    {
        id = "citizen",
        displayName = "المواطن",
        icon = "#citizen-action",
        enableMenu = function() return not isDead() end,
        subMenus = {
            "citizen:carry", "citizen:givecash", "citizen:escort",
            "citizen:putveh", "citizen:unseat", "citizen:911",
        },
    },
    {
        id = "clothing",
        displayName = "الملابس",
        icon = "#Clothing-icon",
        enableMenu = function() return not isDead() end,
        subMenus = {
            "clothing:mask", "clothing:hat", "clothing:glasses", "clothing:watch",
            "clothing:gloves", "clothing:jacket", "clothing:chain", "clothing:reload",
        },
    },
    {
        id = "inventory",
        displayName = "الحقيبة",
        icon = "#house-setstash",
        close = true,
        onSelect = function() ExecuteCommand('openInv') end,
        enableMenu = function() return not isDead() end,
    },
    {
        id = "phone",
        displayName = "الهاتف",
        icon = "#givenum",
        close = true,
        onSelect = function() ExecuteCommand('phone') end,
        enableMenu = function() return not isDead() end,
    },
    {
        id = "vehicle",
        displayName = "السيارة",
        icon = "#vehicle-options",
        enableMenu = function() return not isDead() and cache.vehicle ~= nil end,
        subMenus = {
            "vehicle:engine", "vehicle:xenon",
            "vehicle:win0", "vehicle:win1", "vehicle:win2", "vehicle:win3",
            "seat:driver", "seat:passenger", "seat:rearleft", "seat:rearright",
            "vehicle:hood", "vehicle:trunk", "vehicle:doors", "vehicle:flip",
        },
    },
    {
        id = "police",
        displayName = "الامن العام",
        icon = "#police",
        enableMenu = function() return not isDead() and isPolice() end,
        subMenus = {
            "police:cuff", "police:escort", "police:carry",
            "police:rob", "police:fingerprint", "police:putveh", "police:unseat",
            "police:bill", "police:seizecash",
        },
    },
    {
        id = "ambulance",
        displayName = "الإسعاف",
        icon = "#medic",
        enableMenu = function() return not isDead() and isEMS() end,
        subMenus = { "ems:revive", "ems:check", "ems:heal" },
    },
    {
        id = "radio",
        displayName = "الراديو",
        icon = "#radio",
        enableMenu = function()
            return not isDead() and GetResourceState('pma-voice') == 'started' and (isPolice() or isEMS())
        end,
        subMenus = {
            "radio:one", "radio:two", "radio:three", "radio:four", "radio:five",
            "radio:six", "radio:seven", "radio:eight", "radio:nine", "radio:ten",
            "radio:off",
        },
    },
}

-- ============================================================
-- القوائم الفرعية
-- ============================================================

Config.SubMenus = {
    -- المواطن
    ["citizen:carry"] = {
        title = "حمل", icon = "#cuffs-carry", close = true,
        functiontype = "client", functionName = "police:client:KidnapPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["citizen:givecash"] = {
        title = "اعطاء كاش", icon = "#vehicle-sell", close = true,
        onSelect = giveCash,
        enableMenu = function() return not isDead() end,
    },
    ["citizen:escort"] = {
        title = "سحب", icon = "#general-escort", close = true,
        functiontype = "client", functionName = "police:client:EscortPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["citizen:putveh"] = {
        title = "ادخال بالمركبة", icon = "#general-put-in-veh", close = true,
        functiontype = "client", functionName = "police:client:PutPlayerInVehicle",
        enableMenu = function() return not isDead() end,
    },
    ["citizen:unseat"] = {
        title = "اخراج من المركبة", icon = "#general-unseat-nearest", close = true,
        functiontype = "client", functionName = "police:client:SetPlayerOutVehicle",
        enableMenu = function() return not isDead() end,
    },
    ["citizen:911"] = {
        title = "اتصال 911", icon = "#givenum", close = true,
        onSelect = function()
            TriggerServerEvent('police:server:policeAlert', 'نداء استغاثة: مواطن يطلب المساعدة')
            MTNotify('تم إرسال نداء 911', 'success')
        end,
        enableMenu = function() return not isDead() end,
    },

    -- الملابس
    ["clothing:mask"] = {
        title = "القناع", icon = "#Clothing-Mask", close = true,
        onSelect = function() toggleComponent('mask', 'القناع', 1, 0) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:hat"] = {
        title = "القبعة", icon = "#Clothing-Hat", close = true,
        onSelect = function() toggleProps('hat', 'القبعة', { 0 }) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:glasses"] = {
        title = "النظارات", icon = "#Clothing-Glasses", close = true,
        onSelect = function() toggleProps('glasses', 'النظارات', { 1 }) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:watch"] = {
        title = "السوار", icon = "#clothing-watch", close = true,
        onSelect = function() toggleProps('watch', 'السوار', { 6, 7 }) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:gloves"] = {
        title = "الكفوف", icon = "#Clothing-Gloves", close = true,
        onSelect = function() toggleComponent('gloves', 'الكفوف', 3, 0) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:jacket"] = {
        title = "الملابس", icon = "#Clothing-Shirt", close = true,
        onSelect = function() toggleComponent('jacket', 'الملابس', 11, 0) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:chain"] = {
        title = "السلسلة", icon = "#clothing-chain", close = true,
        onSelect = function() toggleComponent('chain', 'السلسلة', 7, 0) end,
        enableMenu = function() return not isDead() end,
    },
    ["clothing:reload"] = {
        title = "إعادة Skin", icon = "#Clothing-icon", close = true,
        onSelect = function() ExecuteCommand('refreshskin') end,
        enableMenu = function() return not isDead() end,
    },

    -- السيارة
    ["vehicle:engine"] = {
        title = "المحرك", icon = "#veh-engine", close = true,
        onSelect = toggleEngine,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:xenon"] = {
        title = "الزنون", icon = "#veh-xenon", close = true,
        onSelect = toggleXenon,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    -- كل نافذة وحدها: 0 كدام يسار (السايق)، 1 كدام يمين، 2 ورا يسار، 3 ورا يمين
    ["vehicle:win0"] = {
        title = "نافذة السايق", icon = "#veh-window", close = true,
        onSelect = function() toggleWindows({ 0 }, 'نافذة السايق') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:win1"] = {
        title = "نافذة جنب السايق", icon = "#veh-window", close = true,
        onSelect = function() toggleWindows({ 1 }, 'نافذة جنب السايق') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:win2"] = {
        title = "نافذة خلف اليسار", icon = "#veh-window", close = true,
        onSelect = function() toggleWindows({ 2 }, 'نافذة خلف اليسار') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:win3"] = {
        title = "نافذة خلف اليمين", icon = "#veh-window", close = true,
        onSelect = function() toggleWindows({ 3 }, 'نافذة خلف اليمين') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },

    -- المقاعد
    ["seat:driver"] = {
        title = "السايق", icon = "#veh-seat", close = true,
        onSelect = function() switchSeat(-1, 'مقعد السايق') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["seat:passenger"] = {
        title = "جنب السايق", icon = "#veh-seat", close = true,
        onSelect = function() switchSeat(0, 'جنب السايق') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["seat:rearleft"] = {
        title = "خلف اليسار", icon = "#veh-seat", close = true,
        onSelect = function() switchSeat(1, 'خلف اليسار') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["seat:rearright"] = {
        title = "خلف اليمين", icon = "#veh-seat", close = true,
        onSelect = function() switchSeat(2, 'خلف اليمين') end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:hood"] = {
        title = "البونيت", icon = "#vehicle-options", close = true,
        onSelect = function() toggleDoor(4) end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:trunk"] = {
        title = "الشنطة", icon = "#vehicle-options", close = true,
        onSelect = function() toggleDoor(5) end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:doors"] = {
        title = "قفل/فتح الأبواب", icon = "#container-rob", close = true,
        onSelect = function()
            local v = cache.vehicle
            if not v then return end
            local locked = GetVehicleDoorLockStatus(v) == 2
            SetVehicleDoorsLocked(v, locked and 1 or 2)
            MTNotify(locked and 'الأبواب انفتحت' or 'الأبواب انقفلت', 'primary')
        end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },
    ["vehicle:flip"] = {
        title = "تعديل السيارة", icon = "#general-flip-vehicle", close = true,
        onSelect = function()
            local v = cache.vehicle
            if v then SetVehicleOnGroundProperly(v) end
        end,
        enableMenu = function() return cache.vehicle ~= nil end,
    },

    -- البوليس (ترتيب عملياتي: تعامل ← مركبة ← اجراءات)
    ["police:cuff"] = {
        title = "كلبشة / فك", icon = "#police-cuffs", close = true,
        functiontype = "client", functionName = "police:client:CuffPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["police:escort"] = {
        title = "سحب", icon = "#general-escort", close = true,
        functiontype = "client", functionName = "police:client:EscortPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["police:carry"] = {
        title = "حمل", icon = "#cuffs-carry", close = true,
        functiontype = "client", functionName = "police:client:KidnapPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["police:rob"] = {
        title = "تفتيش", icon = "#police-search", close = true,
        functiontype = "client", functionName = "police:client:RobPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["police:fingerprint"] = {
        title = "بصمة", icon = "#police-fingerprint", close = true,
        onSelect = function()
            local playerId = getClosestPlayer(2.5)
            if not playerId then
                MTNotify('ماكو لاعب قريب', 'error')
                return
            end
            TriggerServerEvent('police:server:showFingerprint', playerId)
        end,
        enableMenu = function() return not isDead() end,
    },
    ["police:putveh"] = {
        title = "ادخال بالمركبة", icon = "#general-put-in-veh", close = true,
        functiontype = "client", functionName = "police:client:PutPlayerInVehicle",
        enableMenu = function() return not isDead() end,
    },
    ["police:unseat"] = {
        title = "اخراج من المركبة", icon = "#general-unseat-nearest", close = true,
        functiontype = "client", functionName = "police:client:SetPlayerOutVehicle",
        enableMenu = function() return not isDead() end,
    },
    ["police:bill"] = {
        title = "غرامة", icon = "#bill-icon", close = true,
        functiontype = "client", functionName = "police:client:BillPlayer",
        enableMenu = function() return not isDead() end,
    },
    ["police:seizecash"] = {
        title = "مصادرة كاش", icon = "#police-cash", close = true,
        functiontype = "client", functionName = "police:client:SeizeCash",
        enableMenu = function() return not isDead() end,
    },

    -- الإسعاف
    ["ems:revive"] = {
        title = "إنعاش", icon = "#ems-revive", close = true,
        functiontype = "client", functionName = "hospital:client:RevivePlayer",
        enableMenu = function() return not isDead() and getClosestPlayer(2.5) ~= false end,
    },
    ["ems:check"] = {
        title = "فحص الحالة", icon = "#general-check-over-target", close = true,
        functiontype = "client", functionName = "hospital:client:CheckStatus",
        enableMenu = function() return not isDead() and getClosestPlayer(2.5) ~= false end,
    },
    ["ems:heal"] = {
        title = "علاج", icon = "#ems-heal", close = true,
        functiontype = "client", functionName = "hospital:client:TreatWounds",
        enableMenu = function() return not isDead() and getClosestPlayer(2.5) ~= false end,
    },

    -- الراديو (1-5 الامن العام، 6-10 صحة)
    ["radio:one"]   = { title = "الامن العام 1", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 1, enableMenu = function() return not isDead() and isPolice() end },
    ["radio:two"]   = { title = "الامن العام 2", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 2, enableMenu = function() return not isDead() and isPolice() end },
    ["radio:three"] = { title = "الامن العام 3", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 3, enableMenu = function() return not isDead() and isPolice() end },
    ["radio:four"]  = { title = "الامن العام 4", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 4, enableMenu = function() return not isDead() and isPolice() end },
    ["radio:five"]  = { title = "الامن العام 5", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 5, enableMenu = function() return not isDead() and isPolice() end },
    ["radio:six"]   = { title = "صحة 6", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 6, enableMenu = function() return not isDead() and (isEMS() or isPolice()) end },
    ["radio:seven"] = { title = "صحة 7", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 7, enableMenu = function() return not isDead() and (isEMS() or isPolice()) end },
    ["radio:eight"] = { title = "صحة 8", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 8, enableMenu = function() return not isDead() and (isEMS() or isPolice()) end },
    ["radio:nine"]  = { title = "صحة 9", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 9, enableMenu = function() return not isDead() and (isEMS() or isPolice()) end },
    ["radio:ten"]   = { title = "صحة 10", icon = "#radio-channel", close = true, functiontype = "client", functionName = "qb-radialmenu:client:enter:radio", functionParameters = 10, enableMenu = function() return not isDead() and (isEMS() or isPolice()) end },
    ["radio:off"]   = { title = "إطفاء", icon = "#taxi-power", close = true, functiontype = "client", functionName = "qb-radio:cl:ToggleOnOff", enableMenu = function() return not isDead() and (isPolice() or isEMS()) end },
}
