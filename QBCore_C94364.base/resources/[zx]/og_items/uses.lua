-- OG: استعمال لكل غرض ما إله استعمال بأي سكربت ثاني
-- السكربت ينتظر شوية لحد ما كل السكربتات تسجل أغراضها، وبعدها يضيف استعمال للباقي بس
local QBCore = exports['qb-core']:GetCoreObject()
local pending = {} -- [src] = اسم الغرض اللي ينتظر يخلص (مثل الجليكان)

local function notify(src, msg, t) TriggerClientEvent('QBCore:Notify', src, msg, t or 'primary', 5000) end
local function label(name) local it = QBCore.Shared.Items[name] return it and it.label or name end
local function remove(src, name, n, slot) return exports['qb-inventory']:RemoveItem(src, name, n or 1, slot, 'og_items:use') end
local function add(src, name, n) return exports['qb-inventory']:AddItem(src, name, n or 1, false, false, 'og_items:use') end
local function count(src, name) return exports['qb-inventory']:GetItemCount(src, name) or 0 end
local function box(src, name, kind, n) TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[name], kind, n or 1) end

-- يفكك غرض لغرض ثاني (يحتاج أكياس فاضية إذا انطلبت)
local function breakDown(src, item, out, n, bags)
    if bags and count(src, 'empty_weed_bag') < bags then
        return notify(src, 'تحتاج ' .. bags .. ' ' .. label('empty_weed_bag'), 'error')
    end
    if not exports['qb-inventory']:CanAddItem(src, out, n) then return notify(src, 'الحقيبة مليانة', 'error') end
    TriggerClientEvent('og_items:progress', src, 'تفكيك ' .. label(item.name) .. '...', 6000, 'work', { kind = 'break', item = item.name, slot = item.slot, out = out, n = n, bags = bags })
end

local Materials = { plastic = 1, metalscrap = 1, copper = 1, aluminum = 1, aluminumoxide = 1, iron = 1, ironoxide = 1, steel = 1, rubber = 1, glass = 1 }
local Valuables = { rolex = 2500, diamond_ring = 4000, diamond = 6000, goldchain = 1500, tenkgoldchain = 3000, goldbar = 15000 }
local WeedBags = { weed_whitewidow = 1, weed_skunk = 1, weed_purplehaze = 1, weed_ogkush = 1, weed_amnesia = 1, weed_ak47 = 1 }

local Use = {}

-- أكل وشرب
Use.grape      = function(src, item) if remove(src, item.name, 1, item.slot) then box(src, item.name, 'remove') TriggerClientEvent('og_items:consume', src, 'eat', 15) end end
Use.grapejuice = function(src, item) if remove(src, item.name, 1, item.slot) then box(src, item.name, 'remove') TriggerClientEvent('og_items:consume', src, 'drink', 30) end end
Use.wine       = function(src, item) if remove(src, item.name, 1, item.slot) then box(src, item.name, 'remove') TriggerClientEvent('og_items:consume', src, 'alcohol', 20) end end

-- مخدرات: تفكيك وتلفيف
Use.coke_brick       = function(src, item) breakDown(src, item, 'coke_small_brick', 2) end
Use.coke_small_brick = function(src, item) breakDown(src, item, 'cokebaggy', 10, 10) end
Use.weed_brick       = function(src, item) breakDown(src, item, 'weed_skunk', 10, 10) end
local function rollJoint(src, bagItem)
    if count(src, 'rolling_paper') < 1 then return notify(src, 'تحتاج ' .. label('rolling_paper') .. ' حتى تلف', 'error') end
    TriggerClientEvent('og_items:progress', src, 'تلف سيجارة...', 5000, 'work', { kind = 'joint', item = bagItem })
end
for k in pairs(WeedBags) do Use[k] = function(src, item) rollJoint(src, item.name) end end
Use.rolling_paper = function(src)
    for k in pairs(WeedBags) do if count(src, k) > 0 then return rollJoint(src, k) end end
    notify(src, 'تحتاج كيس حشيش حتى تلف', 'error')
end
Use.empty_weed_bag = function(src) notify(src, 'الأكياس الفاضية تستعملها لتفكيك القوالب (الكوكايين والحشيش)') end

-- تلفونات وأجهزة
for _, k in ipairs({ 'phone', 'iphone', 'samsungphone' }) do Use[k] = function(src) TriggerClientEvent('og_items:phone', src) end end
Use.laptop = function(src) TriggerClientEvent('og_items:tablet', src, 'laptop') end
Use.tablet = function(src) TriggerClientEvent('og_items:tablet', src, 'tablet') end
Use.fitbit = function(src) TriggerClientEvent('og_items:fitbit', src) end
Use.pinger = function(src) TriggerClientEvent('og_items:pinger', src) end
Use.radioscanner = function(src)
    if GetResourceState('ar_dispatch') ~= 'started' then return notify(src, 'ماكو إشارة', 'error') end
    local a = exports['ar_dispatch']:GetAlerts()[1]
    if not a or os.time() - a.time > 600 then return notify(src, 'الماسح ما لگط شي بآخر 10 دقايق') end
    if math.random() < 0.3 then return notify(src, 'الإشارة ضعيفة... جرب مرة ثانية', 'error') end
    local jitter = 60
    TriggerClientEvent('og_items:waypoint', src, a.coords.x + math.random(-jitter, jitter), a.coords.y + math.random(-jitter, jitter), 'الماسح لگط: ' .. a.code .. ' ' .. a.title)
end
Use.cryptostick = function(src, item)
    if not remove(src, item.name, 1, item.slot) then return end
    box(src, item.name, 'remove')
    local amount = math.random(500, 2500)
    local P = QBCore.Functions.GetPlayer(src)
    P.Functions.AddMoney('bank', amount, 'cryptostick')
    notify(src, 'فكيت تشفير الفلاشة وتحولت ' .. amount .. '$ لحسابك', 'success')
end

-- مواد التصنيع: يأشر على أقرب طاولة تصنيع
for k in pairs(Materials) do
    Use[k] = function(src)
        if GetResourceState('og_crafting') ~= 'started' then return notify(src, 'هذي مادة تصنيع') end
        local p, best, bd = GetEntityCoords(GetPlayerPed(src))
        for _, t in ipairs(exports['og_crafting']:GetTables()) do
            local d = #(p - vector3(t.x, t.y, t.z))
            if not bd or d < bd then best, bd = t, d end
        end
        if not best then return notify(src, 'هذي مادة تصنيع') end
        TriggerClientEvent('og_items:waypoint', src, best.x, best.y, 'مادة تصنيع - حطيتلك GPS على ' .. best.label)
    end
end
Use.screwdriverset = function(src) notify(src, 'طقم المفكات يستعمل بالتصنيع (مثل المثقاب)') end
Use.drill = function(src) TriggerClientEvent('og_items:progress', src, 'تشغيل المثقاب...', 3000, 'drill') end

-- ذهب ومجوهرات
for k, v in pairs(Valuables) do
    Use[k] = function(src) TriggerClientEvent('og_items:progress', src, 'تفحص ' .. label(k) .. '...', 3000, 'inspect', { kind = 'msg', msg = 'قيمته التقريبية ' .. v .. '$ - تبيعه بمحل الرهونات' }) end
end
Use.markedbills = function(src, item)
    local w = item.info and item.info.worth or 0
    notify(src, 'فلوس معلّمة' .. (w > 0 and (' - قيمتها ' .. w .. '$') or '') .. '. تحتاج تغسلها')
end
Use.casinochips = function(src, item) notify(src, 'عندك ' .. (item.amount or 1) .. ' رقاقة - تصرفهن بالكازينو') end

-- أوراق ومستندات
local function readDoc(src, item, title)
    local info = item.info or {}
    local txt = info.text or info.label or info.content or info.description
    TriggerClientEvent('og_items:progress', src, 'تقرا ' .. title .. '...', 2500, 'read', { kind = 'msg', msg = txt and (title .. ': ' .. tostring(txt)) or (title .. ' بدون كتابة') })
end
Use.stickynote = function(src, item) readDoc(src, item, 'الملاحظة') end
Use.certificate = function(src, item) readDoc(src, item, 'الشهادة') end
Use.printerdocument = function(src, item) readDoc(src, item, 'المستند') end
Use.empty_evidence_bag = function(src) notify(src, 'كيس الأدلة يتعبى من الأرض (الفشق والدم) بالعين') end
Use.filled_evidence_bag = function(src, item)
    local i = item.info or {}
    local parts = {}
    for _, k in ipairs({ 'label', 'type', 'street', 'bloodtype', 'dnalabel', 'ammolabel', 'serie' }) do if i[k] then parts[#parts + 1] = tostring(i[k]) end end
    notify(src, #parts > 0 and ('دليل: ' .. table.concat(parts, ' | ')) or 'كيس أدلة')
end
Use.labkey = function(src) notify(src, 'مفتاح مختبر - يفتح باب المختبر') end

-- أدوات
Use.walkstick = function(src) TriggerClientEvent('og_items:walkstick', src) end
Use.lighter = function(src) TriggerClientEvent('og_items:progress', src, 'تولع القداحة...', 2000, 'lighter') end
Use.jerry_can = function(src) pending[src] = 'jerry_can' TriggerClientEvent('og_items:refuel', src) end
Use.gatecrack = function(src) notify(src, 'كاسر البوابات يستعمل بالسرقات (البوابات الإلكترونية)') end
Use.trojan_usb = function(src) notify(src, 'فلاشة التروجان تستعمل بالسرقات لتطفي الأنظمة') end
Use.dendrogyra_coral = function(src) notify(src, 'مرجان - تبيعه بمحل الغوص') end
Use.antipatharia_coral = Use.dendrogyra_coral

-- رخص: تنعرض للي يمك (مثل الهوية)
local function showCard(src, item, title)
    local i = item.info or {}
    local P = QBCore.Functions.GetPlayer(src)
    local ci = P and P.PlayerData.charinfo or {}
    local name = (i.firstname or ci.firstname or '') .. ' ' .. (i.lastname or ci.lastname or '')
    local p = GetEntityCoords(GetPlayerPed(src))
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        if #(p - GetEntityCoords(GetPlayerPed(v))) < 3.0 then
            TriggerClientEvent('chat:addMessage', v, {
                template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5,5,5,.6), #3a5a8a);"><strong>{0}</strong><br><strong>الاسم:</strong> {1}<br><strong>رقم المواطن:</strong> {2}</div>',
                args = { title, name, i.citizenid or (P and P.PlayerData.citizenid) or '-' },
            })
        end
    end
end
Use.weaponlicense = function(src, item) showCard(src, item, 'رخصة سلاح') end
Use.lawyerpass = function(src, item) showCard(src, item, 'بطاقة محامٍ') end

-- الهوية ورخصة القيادة يعرضهن qb-inventory بنفسه
local Skip = { id_card = true, driver_license = true }

-- أي غرض ما إله شي من فوك: يتفحصه ويطلع وصفه
local function generic(src, item)
    local it = QBCore.Shared.Items[item.name] or {}
    TriggerClientEvent('og_items:progress', src, 'تفحص ' .. (it.label or item.name) .. '...', 2000, 'inspect', { kind = 'msg', msg = it.label or item.name })
end

-- ===================== نتايج الكلاينت =====================
RegisterNetEvent('og_items:done', function(d)
    local src = source
    if type(d) ~= 'table' then return end
    if d.kind == 'break' then
        local need = { coke_brick = { 'coke_small_brick', 2 }, coke_small_brick = { 'cokebaggy', 10, 10 }, weed_brick = { 'weed_skunk', 10, 10 } }
        local r = need[d.item]
        if not r then return end
        if r[3] and count(src, 'empty_weed_bag') < r[3] then return end
        if not remove(src, d.item, 1) then return end
        box(src, d.item, 'remove')
        if r[3] then remove(src, 'empty_weed_bag', r[3]) box(src, 'empty_weed_bag', 'remove', r[3]) end
        add(src, r[1], r[2]) box(src, r[1], 'add', r[2])
    elseif d.kind == 'joint' then
        if not WeedBags[d.item] or count(src, d.item) < 1 or count(src, 'rolling_paper') < 1 then return end
        remove(src, d.item, 1) remove(src, 'rolling_paper', 1)
        box(src, d.item, 'remove') box(src, 'rolling_paper', 'remove')
        add(src, 'joint', 1) box(src, 'joint', 'add')
    elseif d.kind == 'refuel' then
        if pending[src] ~= 'jerry_can' then return end
        pending[src] = nil
        if remove(src, 'jerry_can', 1) then box(src, 'jerry_can', 'remove') end
    end
end)

RegisterNetEvent('og_items:cancel', function() pending[source] = nil end)

RegisterNetEvent('og_items:ping', function(target)
    local src = source
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > 5.0 then return end
    local c = GetEntityCoords(GetPlayerPed(src))
    TriggerClientEvent('og_items:waypoint', target, c.x, c.y, 'وصلك موقع من جهاز تحديد الموقع')
    notify(src, 'دزيت موقعك', 'success')
end)

AddEventHandler('playerDropped', function() pending[source] = nil end)

-- ===================== التسجيل =====================
local function register()
    local n, names = 0, {}
    for name, it in pairs(QBCore.Shared.Items) do
        if it.type ~= 'weapon' and not Skip[name] and not QBCore.Functions.CanUseItem(name) then
            QBCore.Functions.CreateUseableItem(name, Use[name] or generic)
            n = n + 1
            names[#names + 1] = name
        end
    end
    if n > 0 then print(('^2[og_items]^7 ضفت استعمال لـ %d غرض: %s'):format(n, table.concat(names, ', '))) end
end

CreateThread(function()
    Wait(8000) -- ننتظر باقي السكربتات تسجل أغراضها
    register()
end)

-- إذا سكربت تشغل بعدين، نعيد الفحص
AddEventHandler('onResourceStart', function(r)
    if r == GetCurrentResourceName() then return end
    SetTimeout(3000, register)
end)
