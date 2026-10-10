local RES   = GetCurrentResourceName()
local TOTAL = Config.Slots + Config.HotbarSlots

local Players, Drops, Store = {}, {}, {}
local DropCounter = 0

-- تحميل البيانات المحفوظة
do
    local raw = LoadResourceFile(RES, 'data.json')
    if raw and raw ~= '' then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then Store = t end
    end
end

---------------------------------------------------------------- أدوات مساعدة
local function toInt(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.floor(v)
end

local function round(n) return math.floor(n * 100 + 0.5) / 100 end

local function notify(src, msg, kind)
    TriggerClientEvent('ar_inventory:notify', src, msg, kind or 'info')
end

local function getLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
end

local function label(name)
    local d = Config.Items[name]
    return d and d.label or name
end

local function totalWeight(slots)
    local w = 0
    for _, it in pairs(slots) do
        local d = Config.Items[it.name]
        if d then w = w + d.weight * it.count end
    end
    return round(w)
end

local function sync(src)
    local p = Players[src]
    if not p then return end
    local list = {}
    for i, it in pairs(p.slots) do
        list[#list + 1] = { slot = i, name = it.name, count = it.count }
    end
    TriggerClientEvent('ar_inventory:sync', src, list, totalWeight(p.slots))
end

local function firstFree(p)
    for i = 1, Config.Slots do
        if not p.slots[i] then return i end
    end
end

local function canCarry(src, name, count)
    local p, d = Players[src], Config.Items[name]
    if not p or not d or count < 1 then return false end
    return totalWeight(p.slots) + d.weight * count <= Config.MaxWeight + 0.0001
end

local function getCount(src, name)
    local p = Players[src]
    if not p then return 0 end
    local c = 0
    for _, it in pairs(p.slots) do
        if it.name == name then c = c + it.count end
    end
    return c
end

local reasons = {
    invalid = 'بيانات غير صحيحة',
    weight  = ('لا يمكنك حمل المزيد، الحد الأقصى %s كغم'):format(Config.MaxWeight),
    slots   = 'لا توجد خانة فارغة في الحقيبة',
}

---------------------------------------------------------------- إضافة / حذف
local function addItem(src, name, count)
    count = toInt(count) or 0
    local p, d = Players[src], Config.Items[name]
    if not p or not d or count < 1 then return false, 'invalid' end
    if not canCarry(src, name, count) then return false, 'weight' end

    if d.stack ~= false then
        for i = 1, TOTAL do
            local it = p.slots[i]
            if it and it.name == name then
                it.count = it.count + count
                sync(src)
                return true
            end
        end
        local free = firstFree(p)
        if not free then return false, 'slots' end
        p.slots[free] = { name = name, count = count }
    else
        local frees = {}
        for i = 1, Config.Slots do
            if not p.slots[i] then
                frees[#frees + 1] = i
                if #frees == count then break end
            end
        end
        if #frees < count then return false, 'slots' end
        for _, i in ipairs(frees) do p.slots[i] = { name = name, count = 1 } end
    end
    sync(src)
    return true
end

local function removeItem(src, name, count)
    count = toInt(count) or 0
    local p = Players[src]
    if not p or count < 1 or getCount(src, name) < count then return false end
    for i = 1, TOTAL do
        local it = p.slots[i]
        if it and it.name == name then
            local take = math.min(it.count, count)
            it.count = it.count - take
            count = count - take
            if it.count <= 0 then p.slots[i] = nil end
            if count <= 0 then break end
        end
    end
    sync(src)
    return true
end

local function takeFromSlot(p, slot, amount)
    local it = p.slots[slot]
    it.count = it.count - amount
    if it.count <= 0 then p.slots[slot] = nil end
end

---------------------------------------------------------------- تحميل وحفظ
local function savePlayer(src)
    local p = Players[src]
    if not p then return end
    local out = {}
    for i, it in pairs(p.slots) do
        out[tostring(i)] = { name = it.name, count = it.count }
    end
    Store[p.id] = out
end

local function flush()
    SaveResourceFile(RES, 'data.json', json.encode(Store), -1)
end

local function saveAll()
    for src in pairs(Players) do savePlayer(src) end
    flush()
end

RegisterNetEvent('ar_inventory:load', function()
    local src = source
    local id = getLicense(src) or ('temp:' .. src)
    local saved = Store[id]
    local slots = {}
    if saved then
        for k, v in pairs(saved) do
            local i = tonumber(k)
            if i and i >= 1 and i <= TOTAL and type(v) == 'table' then
                slots[i] = { name = v.name, count = v.count }
            end
        end
    end
    Players[src] = { id = id, slots = slots, lastUse = 0 }
    if not saved then
        for _, s in ipairs(Config.StartItems) do addItem(src, s[1], s[2]) end
    end
    sync(src)
    TriggerClientEvent('ar_inventory:dropsSync', src, Drops)
end)

AddEventHandler('playerDropped', function()
    local src = source
    savePlayer(src)
    Players[src] = nil
    flush()
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then saveAll() end
end)

CreateThread(function()
    while true do
        Wait(300000)
        saveAll()
    end
end)

-- حذف الأغراض المرمية القديمة
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, dr in pairs(Drops) do
            if now - dr.time > Config.DropLifetime then
                Drops[id] = nil
                TriggerClientEvent('ar_inventory:dropRemove', -1, id)
            end
        end
    end
end)

---------------------------------------------------------------- نقل / دمج
RegisterNetEvent('ar_inventory:move', function(from, to, amount)
    local src = source
    local p = Players[src]
    if not p then return end
    from, to = toInt(from), toInt(to)
    if not from or not to or from == to then return end
    if from < 1 or from > TOTAL or to < 1 or to > TOTAL then return end

    local a = p.slots[from]
    if not a then return end
    amount = toInt(amount) or a.count
    if amount < 1 or amount > a.count then amount = a.count end

    local b = p.slots[to]
    local d = Config.Items[a.name]
    local stackable = not d or d.stack ~= false

    if not b then
        if amount == a.count then
            p.slots[to], p.slots[from] = a, nil
        else
            a.count = a.count - amount
            p.slots[to] = { name = a.name, count = amount }
        end
    elseif b.name == a.name and stackable then
        b.count = b.count + amount
        a.count = a.count - amount
        if a.count <= 0 then p.slots[from] = nil end
    elseif amount == a.count then
        p.slots[from], p.slots[to] = b, a
    end
    sync(src)
end)

---------------------------------------------------------------- استخدام
RegisterNetEvent('ar_inventory:use', function(slot)
    local src = source
    local p = Players[src]
    slot = toInt(slot)
    if not p or not slot or slot < 1 or slot > TOTAL then return end

    local it = p.slots[slot]
    if not it then return end
    local d = Config.Items[it.name]
    if not d or not d.usable then
        notify(src, 'هذا الغرض غير قابل للاستخدام', 'error')
        return
    end

    local now = GetGameTimer()
    if now - p.lastUse < Config.UseCooldown then return end
    p.lastUse = now

    local name = it.name
    if d.consume ~= false then
        takeFromSlot(p, slot, 1)
        sync(src)
    end
    if d.serverEvent then TriggerEvent(d.serverEvent, src, name) end
    TriggerClientEvent('ar_inventory:client:use', src, name)
end)

---------------------------------------------------------------- رمي
RegisterNetEvent('ar_inventory:drop', function(slot, amount)
    local src = source
    local p = Players[src]
    slot = toInt(slot)
    if not p or not slot or slot < 1 or slot > TOTAL then return end
    local it = p.slots[slot]
    if not it then return end

    amount = toInt(amount) or it.count
    if amount < 1 or amount > it.count then amount = it.count end

    local c = GetEntityCoords(GetPlayerPed(src))
    DropCounter = DropCounter + 1
    local id = DropCounter
    Drops[id] = { name = it.name, count = amount, x = c.x, y = c.y, z = c.z - 0.9, time = os.time() }

    takeFromSlot(p, slot, amount)
    sync(src)
    TriggerClientEvent('ar_inventory:dropAdd', -1, id, Drops[id])
    notify(src, ('تم رمي %s x%d'):format(label(Drops[id].name), amount), 'info')
end)

RegisterNetEvent('ar_inventory:pickup', function(id)
    local src = source
    id = toInt(id)
    local dr = id and Drops[id]
    if not dr or not Players[src] then return end

    local c = GetEntityCoords(GetPlayerPed(src))
    if #(c - vector3(dr.x, dr.y, dr.z)) > Config.PickupDistance + 2.0 then return end

    local ok, reason = addItem(src, dr.name, dr.count)
    if not ok then
        notify(src, reasons[reason] or reasons.invalid, 'error')
        return
    end
    Drops[id] = nil
    TriggerClientEvent('ar_inventory:dropRemove', -1, id)
    notify(src, ('استلمت %s x%d'):format(label(dr.name), dr.count), 'success')
end)

---------------------------------------------------------------- إعطاء
RegisterNetEvent('ar_inventory:give', function(slot, amount, target)
    local src = source
    local p = Players[src]
    slot, target = toInt(slot), toInt(target)
    if not p or not slot or not target or target == src then return end
    if slot < 1 or slot > TOTAL then return end

    local tp = Players[target]
    local it = p.slots[slot]
    if not tp or not it then
        notify(src, 'لا يوجد لاعب قريب', 'error')
        return
    end

    local sc = GetEntityCoords(GetPlayerPed(src))
    local tc = GetEntityCoords(GetPlayerPed(target))
    if #(sc - tc) > Config.GiveDistance + 1.0 then
        notify(src, 'اللاعب بعيد عنك', 'error')
        return
    end

    amount = toInt(amount) or it.count
    if amount < 1 or amount > it.count then amount = it.count end

    local name = it.name
    local ok, reason = addItem(target, name, amount)
    if not ok then
        notify(src, 'لا يستطيع اللاعب استلام الغرض: ' .. (reasons[reason] or ''), 'error')
        return
    end
    takeFromSlot(p, slot, amount)
    sync(src)
    notify(src, ('أعطيت %s x%d'):format(label(name), amount), 'success')
    notify(target, ('استلمت %s x%d'):format(label(name), amount), 'success')
end)

---------------------------------------------------------------- أوامر الإدارة
-- أضف في server.cfg:  add_ace group.admin ar_inventory.admin allow
local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'ar_inventory.admin')
end

RegisterCommand('giveitem', function(src, args)
    if not isAdmin(src) then return end
    local target, name, count = toInt(args[1]), args[2], toInt(args[3]) or 1
    local function reply(msg, kind)
        if src == 0 then print(msg) else notify(src, msg, kind) end
    end
    if not target or not name or not Config.Items[name] then
        return reply('الاستخدام: /giveitem [رقم اللاعب] [اسم الغرض] [العدد]', 'error')
    end
    local ok, reason = addItem(target, name, count)
    if ok then
        reply(('تم إعطاء %s x%d'):format(label(name), count), 'success')
        notify(target, ('استلمت %s x%d'):format(label(name), count), 'success')
    else
        reply(reasons[reason] or reasons.invalid, 'error')
    end
end, false)

RegisterCommand('clearinv', function(src, args)
    if not isAdmin(src) then return end
    local target = toInt(args[1]) or src
    if Players[target] then
        Players[target].slots = {}
        sync(target)
        notify(target, 'تم تفريغ حقيبتك', 'info')
    end
end, false)

---------------------------------------------------------------- Exports
exports('AddItem', addItem)
exports('RemoveItem', removeItem)
exports('GetItemCount', getCount)
exports('HasItem', function(src, name, count) return getCount(src, name) >= (count or 1) end)
exports('CanCarry', canCarry)
exports('GetWeight', function(src) return Players[src] and totalWeight(Players[src].slots) or 0 end)
