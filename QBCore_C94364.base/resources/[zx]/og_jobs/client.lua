local QBCore = exports['qb-core']:GetCoreObject()

OG = OG or {}            -- واجهة مشتركة مع taxi_client.lua (نفس المورد، نفس الـ Lua)

local onDuty = nil       -- اسم الوظيفة اللي سجلت دخول بيها هسه
local employed = nil     -- الوظيفة اللي أنت موظف بيها (تتخزن بالسيرفر)
local spawned = {}       -- كل الكيانات اللي سويناها (نمسحها لمن يوقف المورد)
local zoneNames = {}
local blips = {}
local Sells = {}         -- أماكن البيع المحفوظة (/jobsell): [job] = { x, y, z, w } (z = مستوى الأرض)
local SavedBlips = {}    -- أيقونات أضفتها بالأمر /jobblip: [job] = { {x,y,z,sprite,color,label}, ... }
local shownBlips = {}    -- أيقونات الوظيفة الظاهرة هسه
local sellPoints = {}    -- [job] = { ped, zone } نقطة البيع المبنية (تنبني لمن تقرب)
local refreshJobBlips, hideJobBlips

---------------------------------------------------------------- أدوات
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function spawnPed(def)
    local hash = loadModel(def.model)
    if not hash then return nil end
    local c = def.coords
    local ped = CreatePed(0, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if def.scenario then TaskStartScenarioInPlace(ped, def.scenario, 0, true) end
    SetModelAsNoLongerNeeded(hash)
    spawned[#spawned + 1] = ped
    return ped
end

local function addBlip(coords, b)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.color or 0)
    SetBlipScale(blip, b.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
    return blip
end

-- أيقونات الخريطة كلها تمر على og_blips: هو يمسح أي أيقونة ثانية، ويشكّل العربي (support-arabic) حتى ما يطلع مربعات
local function addMapBlip(def)
    local ok, blip = pcall(function() return exports['og_blips']:AddBlip(def) end)
    if ok and blip then return blip end
    return addBlip(def.coords, def) -- بدون og_blips: ممكن ينخفي والعربي ما ينشكّل
end

local function removeMapBlip(blip)
    if not blip then return end
    local ok = pcall(function() exports['og_blips']:RemoveBlip(blip) end)
    if not ok then RemoveBlip(blip) end
end

local function notify(msg, kind)
    QBCore.Functions.Notify(msg, kind or 'primary')
end

local function isOn(job)
    return onDuty == job
end

OG.notify = notify
OG.loadModel = loadModel
OG.addBlip = addMapBlip
OG.removeBlip = removeMapBlip
OG.employed = function() return employed end
OG.onDuty = function() return onDuty end

---------------------------------------------------------------- نقطة البيع الخاصة بكل وظيفة
-- المكان: /jobsell (sells.json) يغطي j.sell.coords من ملف الوظيفة. z = مستوى الأرض (نلقاها بالأرض لحظة البناء)
local function sellCoords(job)
    local s = Sells[job]
    if s then return vector4(s.x, s.y, s.z, s.w or 0.0) end
    local j = Config.Jobs[job]
    return j and j.sell and j.sell.coords or nil
end

local function hasSellPoint(job)
    return sellCoords(job) ~= nil
end

---------------------------------------------------------------- جمع / معالجة
local busy = false

local function runStage(job, stageIdx, pointIdx)
    if busy then return end
    local stage = Config.Jobs[job].stages[stageIdx]
    busy = true
    QBCore.Functions.TriggerCallback('og_jobs:cb:begin', function(ok, msg, time)
        if not ok then
            busy = false
            if msg then notify(msg, 'error') end
            return
        end
        QBCore.Functions.Progressbar('og_jobs_' .. job, stage.label, time or stage.time or 5000, false, true, {
            disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
        }, { task = stage.scenario }, {}, {}, function()
            busy = false
            TriggerServerEvent('og_jobs:server:finish', job, stageIdx)
        end, function()
            busy = false
            TriggerServerEvent('og_jobs:server:cancel')
        end)
    end, job, stageIdx, pointIdx)
end

local function sellStage(job, stageIdx, item)
    TriggerServerEvent('og_jobs:server:sell', job, stageIdx, item)
end

-- قائمة البيع (واجهة html/sell.js على يمين الشاشة): اللي عندك من موارد الوظيفة، اضغط على غرض يبيعه كله أو «بيع الكل»
local sellOpen, sellJob = false, nil

local function refreshSell()
    if not sellOpen then return end
    QBCore.Functions.TriggerCallback('og_jobs:cb:sellList', function(list)
        if sellOpen then SendNUIMessage({ action = 'sellUpdate', list = list or {} }) end
    end, sellJob)
end

local function openSellMenu(job)
    if sellOpen then return end
    QBCore.Functions.TriggerCallback('og_jobs:cb:sellList', function(list)
        if not list or sellOpen then return end
        sellOpen, sellJob = true, job
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'sellOpen', title = Config.Jobs[job].label, list = list })
    end, job)
end

RegisterNUICallback('sellClose', function(_, cb)
    sellOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('sellItem', function(data, cb)
    if sellOpen and data then
        sellStage(sellJob, tonumber(data.stage), data.item)
        SetTimeout(600, refreshSell)
    end
    cb('ok')
end)

RegisterNUICallback('sellAll', function(data, cb)
    if sellOpen and data and type(data.stages) == 'table' then
        for _, idx in ipairs(data.stages) do sellStage(sellJob, tonumber(idx)) end
        SetTimeout(900, refreshSell)
    end
    cb('ok')
end)

---------------------------------------------------------------- قائمة الوظيفة
local function openBossMenu(job)
    local j = Config.Jobs[job]
    QBCore.Functions.TriggerCallback('og_jobs:cb:state', function(state)
        if not state then return end
        local next = state.nextXp and (' / ' .. state.nextXp) or ' (أعلى مستوى)'
        local menu = {
            { header = j.label, txt = ('المستوى %d • الخبرة %d%s • مكافأة دخل +%d%%'):format(state.level, state.xp, next, state.bonus), isMenuHeader = true },
        }
        if state.duty then
            for _, tool in ipairs(j.tools or {}) do
                menu[#menu + 1] = { header = 'شراء ' .. tool.label, txt = ('$%d'):format(tool.price), icon = 'fas fa-toolbox', params = { event = 'og_jobs:client:menu', args = { action = 'tool', job = job, item = tool.item } } }
            end
            if not hasSellPoint(job) then -- إذا الوظيفة لها نقطة بيع خاصة يصير البيع هناك
                for idx, stage in ipairs(j.stages or {}) do
                    if stage.type == 'sell' and not stage.station then
                        menu[#menu + 1] = { header = stage.label, icon = stage.icon, params = { event = 'og_jobs:client:menu', args = { action = 'sell', job = job, stage = idx } } }
                    end
                end
            end
            if j.type == 'taxi' then
                menu[#menu + 1] = { header = 'فتح تابلت التكسي', txt = 'طلبات الزبائن والسيارات والمتصدرين (أو اضغط F6)', icon = 'fas fa-tablet', params = { event = 'og_jobs:client:menu', args = { action = 'taxiTablet', job = job } } }
                menu[#menu + 1] = { header = 'إنهاء المشوار', txt = 'يحاسب الزبون على المسافة اللي مشيتها', icon = 'fas fa-flag-checkered', params = { event = 'og_jobs:client:menu', args = { action = 'taxiEnd', job = job } } }
                menu[#menu + 1] = { header = 'إلغاء المشوار', icon = 'fas fa-ban', params = { event = 'og_jobs:client:menu', args = { action = 'taxiCancel', job = job } } }
                menu[#menu + 1] = { header = 'إرجاع السيارة', icon = 'fas fa-rotate-left', params = { event = 'og_jobs:client:menu', args = { action = 'taxiReturn', job = job } } }
            end
        end
        menu[#menu + 1] = { header = 'الاستقالة', txt = 'تترك الوظيفة (رتبتك السابقة ما ترجع)', icon = 'fas fa-person-walking-arrow-right', params = { event = 'og_jobs:client:menu', args = { action = 'quit', job = job } } }
        exports['qb-menu']:openMenu(menu)
    end, job)
end

---------------------------------------------------------------- تسجيل الدخول للدوام (التوظيف يصير من مركز التوظيف فقط)
function login(job)
    if employed == job then return TriggerServerEvent('og_jobs:server:duty', job, true) end
    notify('لازم تتوظف بهذي الوظيفة من مركز التوظيف أول (ساحة ليجن، علامة الاستفهام الصفراء)', 'error')
end

local function logout(job)
    TriggerServerEvent('og_jobs:server:duty', job, false)
    onDuty = nil
    if Config.Jobs[job].type == 'taxi' and OG.returnTaxi then OG.returnTaxi() end
end

---------------------------------------------------------------- أحداث عامة
RegisterNetEvent('og_jobs:client:tp', function(job)
    local j = Config.Jobs[job]
    if not j then return end
    local c = j.boss.coords
    SetEntityCoords(PlayerPedId(), c.x + 1.5, c.y + 1.5, c.z, false, false, false, false)
end)

RegisterNetEvent('og_jobs:client:employment', function(job)
    employed = job
    refreshJobBlips() -- أيقونة تسجيل الدخول تظهر لمن يتوظف وتختفي لمن يستقيل
end)

local function syncEmployment()
    QBCore.Functions.TriggerCallback('og_jobs:cb:employment', function(job, duty)
        employed, onDuty = job, duty
        refreshJobBlips()
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(1500) syncEmployment() end)
CreateThread(function()
    Wait(3000)
    if LocalPlayer.state.isLoggedIn then syncEmployment() end
end)

RegisterNetEvent('og_jobs:client:duty', function(job)
    onDuty = job
    refreshJobBlips()
end)

RegisterNetEvent('og_jobs:client:reset', function()
    busy = false
    if OG.taxiReset then OG.taxiReset() end
    hideJobBlips()
end)

RegisterNetEvent('og_jobs:client:menu', function(data)
    local job = data.job
    if data.action == 'quit' then
        TriggerServerEvent('og_jobs:server:quit', job)
    elseif data.action == 'tool' then
        TriggerServerEvent('og_jobs:server:buyTool', job, data.item)
    elseif data.action == 'sell' then
        sellStage(job, data.stage)
    elseif data.action == 'taxiTablet' then
        if OG.openTablet then OG.openTablet() end
    elseif data.action == 'taxiEnd' then
        TriggerServerEvent('og_jobs:server:taxiEnd')
    elseif data.action == 'taxiCancel' then
        TriggerServerEvent('og_jobs:server:taxiCancel')
    elseif data.action == 'taxiReturn' then
        if OG.returnTaxi then OG.returnTaxi() end
    end
end)

---------------------------------------------------------------- أيقونات الخريطة
-- أيقونة تسجيل الدخول (عربي): تظهر للموظف بهذي الوظيفة فقط. اللي مو موظف ما يشوفها
local function loginBlip(job)
    local j = Config.Jobs[job]
    local b = j.boss.blip or {}
    local c = j.boss.coords
    return {
        coords = vector3(c.x, c.y, c.z), sprite = b.sprite or 477, color = b.color or 5, scale = b.scale or 0.9,
        label = b.label or ('تسجيل دخول ' .. j.label), shortRange = false, -- دائماً على الخريطة المصغرة حتى توصل لها
    }
end

local function sellBlip(job, c)
    local j = Config.Jobs[job]
    local d = j.sell or {}
    local b = d.blip or {}
    local first
    for _, st in ipairs(j.stages or {}) do
        if st.type == 'sell' then first = st break end
    end
    return {
        coords = vector3(c.x, c.y, c.z), sprite = b.sprite or 52, color = b.color or 2, scale = b.scale or 0.85,
        label = b.label or d.label or (first and first.label) or ('بيع ' .. j.label),
    }
end

-- أيقونات الوظيفة: تسجيل الدخول لمن يكون موظف، ونقطة البيع ومناطق الشغل لمن يسجل دخول
local function visibleBlips()
    local list = {}
    if employed and Config.Jobs[employed] then
        list[#list + 1] = loginBlip(employed)
    end
    local job = onDuty
    local j = job and Config.Jobs[job]
    if j then
        local sc = sellCoords(job)
        if sc then list[#list + 1] = sellBlip(job, sc) end
        for _, b in ipairs(j.blips or {}) do list[#list + 1] = b end
        for _, b in ipairs(SavedBlips[job] or {}) do
            list[#list + 1] = { coords = vector3(b.x, b.y, b.z), sprite = b.sprite, color = b.color, scale = 0.9, label = b.label }
        end
    end
    return list
end

function hideJobBlips()
    for _, blip in ipairs(shownBlips) do removeMapBlip(blip) end
    shownBlips = {}
end

function refreshJobBlips()
    hideJobBlips()
    for _, b in ipairs(visibleBlips()) do
        shownBlips[#shownBlips + 1] = addMapBlip(b)
    end
end

---------------------------------------------------------------- نقاط البيع (موظف يشتري بضاعة الوظيفة)
-- نلقى الأرض تحت النقطة بدل ما نعتمد على رقم الارتفاع (يتأكد إن الموظف واقف على الأرض مو داخل الأرض أو طايف)
local function groundAt(c)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local deadline = GetGameTimer() + 2000
    while GetGameTimer() < deadline do
        for _, lift in ipairs({ 3.0, 12.0 }) do
            local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + lift, false)
            if found then return z end
        end
        Wait(100)
    end
    return c.z
end

local function sellOptions(job)
    local j = Config.Jobs[job]
    local options = {}
    for idx, stage in ipairs(j.stages or {}) do
        if stage.type == 'sell' then
            options[#options + 1] = {
                action = function() sellStage(job, idx) end,
                icon = stage.icon or 'fas fa-sack-dollar', label = stage.label,
                canInteract = function() return isOn(job) end,
            }
        end
    end
    return options
end

local function clearSellPoint(job)
    local sp = sellPoints[job]
    if not sp then return end
    if sp.ped then
        exports['qb-target']:RemoveTargetEntity(sp.ped)
        if DoesEntityExist(sp.ped) then DeleteEntity(sp.ped) end
    end
    if sp.zone then exports['qb-target']:RemoveZone(sp.zone) end
    sellPoints[job] = nil
end

local function buildSellPoint(job)
    local c = sellCoords(job)
    if not c or sellPoints[job] then return end
    local sp = {}
    sellPoints[job] = sp -- نحجزها قبل أي انتظار حتى ما تنبني مرتين
    local d = Config.Jobs[job].sell or {}
    local z = groundAt(c)
    local hash = not d.noPed and loadModel(d.model or 'a_m_m_farmer_01') or nil -- noPed = بدون موظف: منطقة تفاعل عند باب/مكان
    if sellPoints[job] ~= sp then return end -- انمسحت أثناء التحميل
    if hash then
        local ped = CreatePed(0, hash, c.x, c.y, z, c.w, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        if d.scenario ~= false then TaskStartScenarioInPlace(ped, d.scenario or 'WORLD_HUMAN_CLIPBOARD', 0, true) end
        SetModelAsNoLongerNeeded(hash)
        sp.ped = ped -- الموظف للشكل بس، البيع بحرف E (شوف الحلقة تحت)
    end
end

-- البيع بحرف E: لمن توصل لنقطة البيع وانت على الدوام يطلع نص «اضغط E» وتفتح قائمة اللي عندك
CreateThread(function()
    local shown = false
    local function hint(on)
        if on == shown then return end
        shown = on
        pcall(function()
            if on then exports['qb-core']:DrawText('[E] بيع', 'left') else exports['qb-core']:HideText() end
        end)
    end
    while true do
        local wait = 500
        local job = onDuty
        local sc = job and sellCoords(job)
        if sc then
            local p = GetEntityCoords(PlayerPedId())
            local r = (Config.Jobs[job].sell and Config.Jobs[job].sell.distance) or 3.0
            if #(vector2(p.x, p.y) - vector2(sc.x, sc.y)) <= r then
                wait = 0
                hint(true)
                if IsControlJustReleased(0, 38) then openSellMenu(job) end
            else
                hint(false)
            end
        else
            hint(false)
        end
        Wait(wait)
    end
end)

-- ننشئ نقطة البيع لمن تقرب منها وننظفها لمن تبعد (ما نحتاج 6 موظفين شغالين على الخريطة كلها)
CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for job in pairs(Config.Jobs) do
            local sc = sellCoords(job)
            if sc then
                local dist = #(vector2(p.x, p.y) - vector2(sc.x, sc.y))
                if dist < 80.0 and not sellPoints[job] then
                    buildSellPoint(job)
                elseif dist > 140.0 and sellPoints[job] then
                    clearSellPoint(job)
                end
            end
        end
        Wait(1500)
    end
end)

---------------------------------------------------------------- باب الشركة (تسجيل دخول / خروج / قائمة الوظيفة)
function buildDoor(job)
    local j = Config.Jobs[job]
    local bc = j.boss.coords
    local zoneName = 'og_jobs_door_' .. job
    exports['qb-target']:RemoveZone(zoneName)
    zoneNames[#zoneNames + 1] = zoneName
    local options = {
        {
            action = function() login(job) end,
            icon = 'fas fa-right-to-bracket', label = 'تسجيل دخول',
            canInteract = function() return employed == job and onDuty ~= job end,
        },
        {
            action = function() logout(job) end,
            icon = 'fas fa-right-from-bracket', label = 'تسجيل خروج',
            canInteract = function() return employed == job and onDuty == job end,
        },
        {
            action = function() openBossMenu(job) end,
            icon = j.icon, label = 'قائمة ' .. j.label,
            canInteract = function() return employed == job end,
        },
        {
            action = function()
                local c = Config.Center and Config.Center.coords
                if c then SetNewWaypoint(c.x, c.y) end
                notify('للتوظيف بـ ' .. j.label .. ' روح لمركز التوظيف، حددت لك موقعه على الخريطة')
            end,
            icon = 'fas fa-briefcase', label = 'كيف أتوظف؟',
            canInteract = function() return employed ~= job end,
        },
    }
    -- وظيفة بدون نقطة بيع خاصة: البيع يصير هنا عند الباب
    if not hasSellPoint(job) then
        for idx, stage in ipairs(j.stages or {}) do
            if stage.type == 'sell' and not stage.station then
                options[#options + 1] = {
                    action = function() sellStage(job, idx) end,
                    icon = stage.icon or 'fas fa-sack-dollar', label = stage.label,
                    canInteract = function() return isOn(job) end,
                }
            end
        end
    end
    -- الخيار يظهر لمن تصوّب على أي نقطة داخل هذا الصندوق (الأرض أو الباب)، فخليته واسع
    exports['qb-target']:AddBoxZone(zoneName, vector3(bc.x, bc.y, bc.z + 1.0), 14.0, 14.0, {
        name = zoneName, heading = bc.w, debugPoly = Config.DebugZones or false, minZ = bc.z - 2.0, maxZ = bc.z + 7.0,
    }, { options = options, distance = 7.0 })
end

---------------------------------------------------------------- بناء العالم (موظفين، محطات، نقاط جمع)
-- فحص: /jobinfo يطبع حالتك وبعدك عن باب كل وظيفة ونقطة بيعها، و/jobzones يرسم حدود المناطق
RegisterCommand('jobinfo', function()
    local p = GetEntityCoords(PlayerPedId())
    notify(('موظف: %s | دوام: %s'):format(employed or 'لا', onDuty or 'لا'))
    for job, j in pairs(Config.Jobs) do
        local c = j.boss.coords
        local d = #(p - vector3(c.x, c.y, c.z))
        local sc = sellCoords(job)
        local sd = sc and #(vector2(p.x, p.y) - vector2(sc.x, sc.y)) or nil
        print(('[og_jobs] %s: الباب %.1f م منك (%.1f, %.1f, %.1f) | البيع: %s'):format(job, d, c.x, c.y, c.z, sd and ('%.1f م'):format(sd) or 'عند الباب'))
    end
    notify('شوف F8 لبعد الأبواب ونقاط البيع')
end, false)

RegisterCommand('jobzones', function()
    Config.DebugZones = not Config.DebugZones
    for job in pairs(Config.Jobs) do buildDoor(job) end
    notify('حدود المناطق: ' .. (Config.DebugZones and 'تشتغل' or 'مقفولة'))
end, false)

RegisterNetEvent('og_jobs:client:blipsUpdated', function(job, list)
    SavedBlips[job] = list
    if onDuty == job then refreshJobBlips() end
end)

RegisterNetEvent('og_jobs:client:sellUpdated', function(job, c)
    if not Config.Jobs[job] then return end
    Sells[job] = c
    clearSellPoint(job) -- تنبني من جديد بالمكان الجديد لمن تقرب
    buildDoor(job)
    refreshJobBlips()
end)

RegisterNetEvent('og_jobs:client:doorUpdated', function(job, c)
    if not Config.Jobs[job] then return end
    Config.Jobs[job].boss.coords = vector4(c.x, c.y, c.z, c.w)
    buildDoor(job)
    refreshJobBlips()
end)

CreateThread(function()
    -- أماكن الأبواب المحفوظة (/jobdoor) تغطي الإحداثيات اللي بملفات الوظائف
    local p = promise.new()
    QBCore.Functions.TriggerCallback('og_jobs:cb:doors', function(d) p:resolve(d) end)
    local saved = Citizen.Await(p) or {}
    for job, c in pairs(saved.doors or {}) do
        if Config.Jobs[job] then Config.Jobs[job].boss.coords = vector4(c.x, c.y, c.z, c.w) end
    end
    Sells = saved.sells or {}
    SavedBlips = saved.blips or {}

    for job, j in pairs(Config.Jobs) do
        buildDoor(job)

        -- المراحل
        for idx, stage in ipairs(j.stages or {}) do
            if stage.type == 'gather' then
                for pIdx, point in ipairs(stage.points) do
                    local name = ('og_jobs_%s_%d_%d'):format(job, idx, pIdx)
                    zoneNames[#zoneNames + 1] = name
                    exports['qb-target']:AddCircleZone(name, point.coords, point.radius or 5.0, { name = name, useZ = false, debugPoly = false }, {
                        options = { {
                            action = function() runStage(job, idx, pIdx) end,
                            icon = stage.icon or 'fas fa-hand', label = stage.label,
                            canInteract = function() return isOn(job) and not busy end,
                        } },
                        distance = 4.0,
                    })
                end
            elseif stage.station and (stage.type == 'process' or stage.type == 'sell') then
                local ped = spawnPed(stage.station)
                if ped then
                    exports['qb-target']:AddTargetEntity(ped, {
                        options = { {
                            action = function()
                                if stage.type == 'process' then runStage(job, idx) else sellStage(job, idx) end
                            end,
                            icon = stage.icon or 'fas fa-gears', label = stage.label,
                            canInteract = function() return isOn(job) and not busy end,
                        } },
                        distance = 2.5,
                    })
                end
            end
        end
    end
    refreshJobBlips() -- الأماكن المحفوظة وصلت: نحدّث الأيقونات
end)

---------------------------------------------------------------- مركز التوظيف
-- الواجهة (html/center.js): الوظائف + وظيفتي + المتصدرين. التقديم والاستقالة يصيرون من هنا فقط
local centerPed, centerBlip
local centerOpen = false

local function itemLabel(name)
    local it = QBCore.Shared.Items[name]
    return it and it.label or name
end

-- معلومات الوظيفة من ملف إعداداتها (أي وظيفة جديدة تظهر بالمركز تلقائياً)
local function buildJobInfo(job, j)
    local info = { id = job, label = j.label, emoji = j.emoji or '💼', desc = j.desc or '', steps = {}, tools = {} }
    if j.type == 'taxi' then
        info.steps[#info.steps + 1] = { label = 'طلبات الزبائن (لاعبين)', level = 1 }
        info.steps[#info.steps + 1] = { label = 'مشاوير VIP', level = j.vipLevel or 3 }
        for _, v in ipairs(j.vehicles or {}) do
            if (v.minLevel or 1) > 1 then info.steps[#info.steps + 1] = { label = 'سيارة: ' .. v.label, level = v.minLevel } end
        end
        info.top = ('$%g + $%g / متر'):format(j.fare.base, j.fare.perMeter)
    else
        local bestPrice, bestItem = 0, nil
        for _, stage in ipairs(j.stages or {}) do
            info.steps[#info.steps + 1] = { label = stage.label, level = stage.type == 'sell' and 0 or (stage.minLevel or 1) }
            if stage.type == 'sell' then
                for item, price in pairs(stage.prices or {}) do
                    if price > bestPrice then bestPrice, bestItem = price, item end
                end
            end
        end
        if bestItem then info.top = ('$%d / %s'):format(bestPrice, itemLabel(bestItem)) end
    end
    for _, t in ipairs(j.tools or {}) do info.tools[#info.tools + 1] = { label = t.label, price = t.price } end
    return info
end

local function openCenter()
    if centerOpen then return end
    QBCore.Functions.TriggerCallback('og_jobs:cb:centerData', function(data)
        if not data then return notify('ما كدرت أفتح مركز التوظيف، قرّب من الموظف', 'error') end
        local p = GetEntityCoords(PlayerPedId())
        local list = {}
        for job, j in pairs(Config.Jobs) do
            local info = buildJobInfo(job, j)
            local c = j.boss.coords
            info.dist = math.floor(#(p - vector3(c.x, c.y, c.z)))
            list[#list + 1] = info
        end
        table.sort(list, function(a, b) return a.label < b.label end)
        data.list = list
        centerOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'centerOpen', data = data })
    end)
end

RegisterNUICallback('centerClose', function(_, cb)
    centerOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('centerRefresh', function(_, cb)
    QBCore.Functions.TriggerCallback('og_jobs:cb:centerData', function(data) cb(data or {}) end)
end)

RegisterNUICallback('centerApply', function(data, cb)
    QBCore.Functions.TriggerCallback('og_jobs:cb:apply', function(ok, msg)
        if not ok and msg then notify(msg, 'error') end
        cb({ ok = ok and true or false })
    end, data and data.job)
end)

RegisterNUICallback('centerQuit', function(_, cb)
    QBCore.Functions.TriggerCallback('og_jobs:cb:quit', function(ok, msg)
        if not ok and msg then notify(msg, 'error') end
        cb({ ok = ok and true or false })
    end)
end)

RegisterNUICallback('centerGps', function(data, cb)
    local j = data and Config.Jobs[data.job]
    if j then
        SetNewWaypoint(j.boss.coords.x, j.boss.coords.y)
        notify('حددت لك موقع ' .. j.label .. ' على الخريطة', 'success')
    end
    cb('ok')
end)

-- يبني (أو يعيد بناء) موظف المركز والأيقونة (بعد /jobcenter ينتقل المكان)
local function buildCenter()
    local c = Config.Center
    if not c then return end
    if centerPed then
        exports['qb-target']:RemoveTargetEntity(centerPed)
        if DoesEntityExist(centerPed) then DeleteEntity(centerPed) end
        centerPed = nil
    end
    if centerBlip then removeMapBlip(centerBlip) centerBlip = nil end
    centerPed = spawnPed(c)
    if centerPed then
        exports['qb-target']:AddTargetEntity(centerPed, {
            options = { { action = function() openCenter() end, icon = 'fas fa-briefcase', label = 'مركز التوظيف' } },
            distance = 2.5,
        })
    end
    if c.blip then
        -- عبر og_blips وإلا ينمسح. shortRange=false: يبين دائماً على الخريطة
        centerBlip = addMapBlip({ coords = vector3(c.coords.x, c.coords.y, c.coords.z), sprite = c.blip.sprite, color = c.blip.color, scale = c.blip.scale, label = c.blip.label, shortRange = false })
    end
end

RegisterNetEvent('og_jobs:client:centerUpdated', function(c)
    Config.Center.coords = vector4(c.x, c.y, c.z, c.w)
    buildCenter()
end)

CreateThread(function()
    local p = promise.new()
    QBCore.Functions.TriggerCallback('og_jobs:cb:doors', function(d) p:resolve(d) end)
    local saved = Citizen.Await(p) or {}
    if saved.center then Config.Center.coords = vector4(saved.center.x, saved.center.y, saved.center.z, saved.center.w) end
    buildCenter()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if centerOpen or sellOpen then SetNuiFocus(false, false) end
    for _, e in ipairs(spawned) do
        exports['qb-target']:RemoveTargetEntity(e)
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    for job in pairs(sellPoints) do clearSellPoint(job) end
    for _, n in ipairs(zoneNames) do exports['qb-target']:RemoveZone(n) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    hideJobBlips()
    if OG.taxiCleanup then OG.taxiCleanup() end
end)
