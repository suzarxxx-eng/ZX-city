-- ===================== ورشة OG: بناء الطاولة =====================
-- الطاولة تنبني محلياً (عند اللاعب بس) لمن يقرب منها، وتنشال لمن يبتعد
local S = Config.Station
local tables, built = {}, {}   -- built[i] = { obj, model, center, d }
local blips = {}
local editing = nil            -- رقم الطاولة اللي تنعدل هسه
local pendingEdit = nil        -- طاولة جديدة تنتظر تنبني حتى تبدي تعديلها

local function load(m)
    if not IsModelInCdimage(m) then return false end
    RequestModel(m)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(m)
end

local function benchModel()
    for _, b in ipairs(S.bench) do if load(b) then return b end end
end

-- مكان الموديل بالعالم: d.x/d.y نص الطاولة، d.z أسفلها، d.h اتجاهها
local function worldPos(m, d)
    local mn, mx = GetModelDimensions(m)
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    local heading = ((d.h or 0.0) + (S.front or 0.0)) % 360.0
    local r = math.rad(heading)
    return d.x - (cx * math.cos(r) - cy * math.sin(r)), d.y - (cx * math.sin(r) + cy * math.cos(r)), d.z - mn.z, heading, mx.z - mn.z
end

local function target(o)
    exports['qb-target']:AddTargetEntity(o, {
        options = { { icon = 'fas fa-screwdriver-wrench', label = 'فتح ' .. Config.Title, action = function() TriggerServerEvent('og_crafting:open') end } },
        distance = Config.Distance,
    })
end

local function spawnStation(i, d)
    local m = benchModel()
    if not m then return end
    local dd = { x = d.x, y = d.y, z = d.z, h = d.h }
    if not d.fixed then -- أول مرة: نلزقها بالأرض
        local found, gz = GetGroundZFor_3dCoord(d.x, d.y, d.z + 1.5, false)
        if found and math.abs(gz - d.z) < 3.0 then dd.z = gz end
    end
    local x, y, z, h, ht = worldPos(m, dd)
    local o = CreateObjectNoOffset(m, x, y, z, false, false, false)
    SetEntityHeading(o, h)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    SetModelAsNoLongerNeeded(m)
    target(o)
    built[i] = { obj = o, model = m, d = dd, center = vector3(dd.x, dd.y, dd.z + ht) }
end

local function removeStation(i)
    local b = built[i]
    if not b then return end
    pcall(function() exports['qb-target']:RemoveTargetEntity(b.obj) end)
    pcall(function() exports['qb-target']:RemoveZone('og_craft_' .. i) end)
    if DoesEntityExist(b.obj) then DeleteObject(b.obj) end
    built[i] = nil
end

local function clearAll()
    for i in pairs(built) do removeStation(i) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

-- يبني ويشيل حسب المسافة
CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for i, d in ipairs(tables) do
            local dist = #(p - vector3(d.x, d.y, d.z))
            if dist < 70.0 and not built[i] then spawnStation(i, d)
            elseif dist > 100.0 and built[i] and editing ~= i then removeStation(i) end
        end
        Wait(1000)
    end
end)

-- ضوء برتقالي خفيف فوك الطاولة
CreateThread(function()
    while true do
        local sleep = 1000
        local p = GetEntityCoords(PlayerPedId())
        for _, b in pairs(built) do
            if #(p - b.center) < 30.0 then
                sleep = 0
                local g = S.glow
                DrawLightWithRange(b.center.x, b.center.y, b.center.z + 0.6, g.r, g.g, g.b, 3.0, 2.5)
            end
        end
        Wait(sleep)
    end
end)

-- ===================== التحكم بالطاولة (للأدمن) =====================
local Help = [[
<b>تحكم بالطاولة</b><br>
الأسهم ← ↑ → ↓ : تحريك<br>
Page Up / Page Down : صعود / نزول<br>
Q / E : لف يسار / يمين<br>
Shift : أسرع &nbsp;|&nbsp; Alt : أبطأ<br>
G : لزقها بالأرض<br>
Enter : حفظ &nbsp;|&nbsp; Backspace : إلغاء]]

local function startEdit(i)
    local b = built[i]
    if not b or editing then return end
    editing = i
    local o, m = b.obj, b.model
    local d = { x = b.d.x, y = b.d.y, z = b.d.z, h = b.d.h or 0.0 }
    local orig = { x = d.x, y = d.y, z = d.z, h = d.h }
    SetEntityDrawOutline(o, true)
    SetEntityDrawOutlineColor(255, 150, 40, 255)
    SetEntityAlpha(o, 220, false)
    exports['qb-core']:DrawText(Help, 'left')

    CreateThread(function()
        local done
        while not done do
            Wait(0)
            -- نوقف حركة اللاعب والأزرار اللي نستعملها
            for _, c in ipairs({ 21, 19, 44, 38, 47, 172, 173, 174, 175, 10, 11, 191, 177, 194, 200, 24, 25, 140, 141, 142 }) do DisableControlAction(0, c, true) end
            local fast = IsDisabledControlPressed(0, 21)
            local slow = IsDisabledControlPressed(0, 19)
            local step = fast and 0.08 or (slow and 0.005 or 0.025)
            local rstep = fast and 3.0 or (slow and 0.25 or 1.0)

            -- التحريك حسب اتجاه الكاميرا
            local cam = math.rad(GetGameplayCamRot(2).z)
            local fx, fy = -math.sin(cam), math.cos(cam)
            local rx, ry = math.cos(cam), math.sin(cam)
            local mx, my = 0.0, 0.0
            if IsDisabledControlPressed(0, 172) then mx, my = mx + fx, my + fy end
            if IsDisabledControlPressed(0, 173) then mx, my = mx - fx, my - fy end
            if IsDisabledControlPressed(0, 175) then mx, my = mx + rx, my + ry end
            if IsDisabledControlPressed(0, 174) then mx, my = mx - rx, my - ry end
            d.x, d.y = d.x + mx * step, d.y + my * step
            if IsDisabledControlPressed(0, 10) then d.z = d.z + step * 0.5 end
            if IsDisabledControlPressed(0, 11) then d.z = d.z - step * 0.5 end
            if IsDisabledControlPressed(0, 44) then d.h = (d.h + rstep) % 360.0 end
            if IsDisabledControlPressed(0, 38) then d.h = (d.h - rstep) % 360.0 end
            if IsDisabledControlJustPressed(0, 47) then
                local found, gz = GetGroundZFor_3dCoord(d.x, d.y, d.z + 2.0, false)
                if found then d.z = gz end
            end

            local x, y, z, h = worldPos(m, d)
            SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
            SetEntityHeading(o, h)

            if IsDisabledControlJustPressed(0, 191) then
                done = 'save'
            elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then
                done = 'cancel'
            end
        end

        exports['qb-core']:HideText()
        SetEntityDrawOutline(o, false)
        ResetEntityAlpha(o)
        editing = nil
        if done == 'save' then
            local t = tables[i]
            TriggerServerEvent('og_crafting:saveEdit', { cfg = t and t.cfg, ex = t and t.ex }, d.x, d.y, d.z, d.h)
        else
            local x, y, z, h = worldPos(m, orig)
            SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
            SetEntityHeading(o, h)
            TriggerEvent('QBCore:Notify', 'انلغى التعديل', 'error')
        end
    end)
end

local function nearestBuilt(maxd)
    local p = GetEntityCoords(PlayerPedId())
    local bi, bd
    for i, b in pairs(built) do
        local dist = #(p - b.center)
        if dist < (maxd or 10.0) and (not bd or dist < bd) then bi, bd = i, dist end
    end
    return bi
end

RegisterNetEvent('og_crafting:edit', function()
    local i = nearestBuilt()
    if not i then return TriggerEvent('QBCore:Notify', 'ماكو طاولة قريبة (قرب أقل من 10 متر)', 'error') end
    startEdit(i)
end)

-- طاولة جديدة انضافت: نبدي نعدلها أول ما تنبني
RegisterNetEvent('og_crafting:editNew', function(ex)
    pendingEdit = ex
    CreateThread(function()
        local t = GetGameTimer() + 6000
        while pendingEdit and GetGameTimer() < t do
            for i, d in ipairs(tables) do
                if d.ex == pendingEdit and built[i] then pendingEdit = nil startEdit(i) return end
            end
            Wait(200)
        end
        pendingEdit = nil
    end)
end)

-- ===================== استلام الطاولات =====================
RegisterNetEvent('og_crafting:tables', function(list)
    if editing then return end
    clearAll()
    tables = list
    if Config.Blips then
        for _, d in ipairs(list) do
            local b = AddBlipForCoord(d.x, d.y, d.z)
            SetBlipSprite(b, 566) SetBlipScale(b, 0.7) SetBlipColour(b, 47) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(Config.Title) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('og_crafting:getTables')
end)

-- فحص: يطلعلك وين أقرب طاولة وهل انبنت
RegisterCommand('ogcraftinfo', function()
    local p = GetEntityCoords(PlayerPedId())
    local best, bd, bi
    for i, d in ipairs(tables) do
        local dist = #(p - vector3(d.x, d.y, d.z))
        if not bd or dist < bd then best, bd, bi = d, dist, i end
    end
    if not best then
        return TriggerEvent('QBCore:Notify', 'ماكو طاولات. حط وحدة بـ /ogcraftadd', 'error', 8000)
    end
    TriggerEvent('QBCore:Notify', ('طاولات: %d | أقرب وحدة: %.0f متر | انبنت: %s'):format(#tables, bd, built[bi] and 'اي' or 'لا'), 'primary', 10000)
    SetNewWaypoint(best.x, best.y)
end, false)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if editing then exports['qb-core']:HideText() end
    clearAll()
end)
