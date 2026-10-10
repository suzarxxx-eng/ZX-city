local QBCore = exports['qb-core']:GetCoreObject()
local busy = {}     -- [src] = { idx, qty, ends }
local extra = {}    -- طاولات مضافة من اللعبة
local rot = {}      -- لفة إضافية لطاولات config.lua (من /ogcraftrotate)

-- ===================== الطاولات =====================
local function loadExtra()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'tables.json')
    local d = raw and json.decode(raw) or {}
    if d.extra then extra, rot = d.extra, d.rot or {} else extra = d end
end

local function saveExtra()
    SaveResourceFile(GetCurrentResourceName(), 'tables.json', json.encode({ extra = extra, rot = rot }, { indent = true }), -1)
end

local function allTables()
    local list = {}
    for i, t in ipairs(Config.Tables) do
        list[#list + 1] = { label = t.label, x = t.coords.x, y = t.coords.y, z = t.coords.z, h = (t.coords.w + (rot['c' .. i] or 0)) % 360, cfg = i, fixed = true }
    end
    for i, t in ipairs(extra) do t.ex = i list[#list + 1] = t end
    return list
end

local function nearestTable(src, maxd)
    local p = GetEntityCoords(GetPlayerPed(src))
    local best, bd
    for _, t in ipairs(allTables()) do
        local d = #(p - vector3(t.x, t.y, t.z))
        if d < (maxd or 8.0) and (not bd or d < bd) then best, bd = t, d end
    end
    return best
end

local function nearTable(src)
    local p = GetEntityCoords(GetPlayerPed(src))
    for _, t in ipairs(allTables()) do
        if #(p - vector3(t.x, t.y, t.z)) <= Config.ServerDistance then return t end
    end
end

loadExtra()
exports('GetTables', allTables)

RegisterNetEvent('og_crafting:getTables', function()
    TriggerClientEvent('og_crafting:tables', source, allTables())
end)

QBCore.Commands.Add('ogcraftadd', 'إضافة طاولة تصنيع بمكانك', { { name = 'الاسم', help = 'اسم الورشة (اختياري)' } }, false, function(src, args)
    local ped = GetPlayerPed(src)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local fwd = vector3(-math.sin(math.rad(h)), math.cos(math.rad(h)), 0.0)
    local p = c + fwd * 1.8
    extra[#extra + 1] = {
        label = (#args > 0 and table.concat(args, ' ')) or Config.Title,
        x = p.x, y = p.y, z = c.z - 0.98, h = (h + 180.0) % 360.0,
    }
    saveExtra()
    TriggerClientEvent('og_crafting:tables', -1, allTables())
    TriggerClientEvent('og_crafting:editNew', src, #extra)
end, 'admin')

QBCore.Commands.Add('ogcraftedit', 'تحريك أقرب طاولة تصنيع (لف، صعود، نزول، تحريك)', {}, false, function(src)
    TriggerClientEvent('og_crafting:edit', src)
end, 'admin')

RegisterNetEvent('og_crafting:saveEdit', function(key, x, y, z, h)
    local src = source
    if not QBCore.Functions.HasPermission(src, 'admin') then return end
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    if not (x and y and z and h) or type(key) ~= 'table' then return end
    local t
    if key.ex and extra[key.ex] then t = extra[key.ex]
    elseif key.cfg and Config.Tables[key.cfg] then
        -- طاولة من config.lua: نحولها لطاولة محفوظة حتى تنحفظ تعديلاتها
        local c = Config.Tables[key.cfg]
        return TriggerClientEvent('QBCore:Notify', src, 'هاي الطاولة من config.lua، غير مكانها من الملف (' .. c.label .. ')', 'error')
    end
    if not t then return end
    t.x, t.y, t.z, t.h, t.fixed = x, y, z, h % 360.0, true
    saveExtra()
    TriggerClientEvent('og_crafting:tables', -1, allTables())
    TriggerClientEvent('QBCore:Notify', src, 'انحفظ مكان الطاولة', 'success')
end)

QBCore.Commands.Add('ogcraftremove', 'شيل أقرب طاولة تصنيع (المضافة من اللعبة)', {}, false, function(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    local best, bd
    for i, t in ipairs(extra) do
        local d = #(c - vector3(t.x, t.y, t.z))
        if d < 8.0 and (not bd or d < bd) then best, bd = i, d end
    end
    if not best then
        return TriggerClientEvent('QBCore:Notify', src, 'ماكو طاولة مضافة قريبة (طاولات config.lua تنشال من الملف)', 'error')
    end
    table.remove(extra, best)
    saveExtra()
    TriggerClientEvent('og_crafting:tables', -1, allTables())
    TriggerClientEvent('QBCore:Notify', src, 'انشالت الطاولة', 'success')
end, 'admin')

QBCore.Commands.Add('ogcraftrotate', 'لف أقرب طاولة تصنيع 90 درجة', {}, false, function(src)
    local t = nearestTable(src)
    if not t then return TriggerClientEvent('QBCore:Notify', src, 'ماكو طاولة قريبة', 'error') end
    if t.cfg then rot['c' .. t.cfg] = ((rot['c' .. t.cfg] or 0) + 90) % 360
    else extra[t.ex].h = (extra[t.ex].h + 90.0) % 360.0 end
    saveExtra()
    TriggerClientEvent('og_crafting:tables', -1, allTables())
end, 'admin')

-- ===================== المستوى =====================
local function getXp(Player)
    return tonumber(Player.PlayerData.metadata[Config.MetaKey]) or 0
end

local function levelOf(xp)
    local lv = 0
    for i = 0, Config.MaxLevel do
        if xp >= Config.Levels[i].xp then lv = i end
    end
    return lv
end

local function craftTime(r, qty, lv)
    local mult = math.max(0.4, 1.0 - lv * Config.SpeedPerLevel)
    return math.floor(r.time * 1000 * qty * mult)
end

local function counts(Player)
    local c = {}
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name then c[it.name] = (c[it.name] or 0) + (it.amount or 0) end
    end
    return c
end

local function itemInfo(name)
    local it = QBCore.Shared.Items[name]
    if not it then return { label = name, image = name .. '.png', desc = '' } end
    return { label = it.label, image = it.image or (name .. '.png'), desc = it.description or '' }
end

-- المواد + المخطوطة (للأسلحة النارية)
local function blueprintOf(r)
    if not (Config.Blueprints and Config.Blueprints.cats[r.cat]) then return end
    local bp = 'blueprint_' .. r.item:gsub('^weapon_', '')
    if QBCore.Shared.Items[bp] then return bp end
end

local function recipeMats(r)
    local list = {}
    for _, m in ipairs(r.mats) do list[#list + 1] = { m[1], m[2] } end
    local bp = blueprintOf(r)
    if bp then table.insert(list, 1, { bp, 1, true }) end -- المخطوطة أول وحدة
    return list
end

local function payload(src, tbl)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local xp = getXp(Player)
    local lv = levelOf(xp)
    local have = counts(Player)
    local recipes = {}
    for i, r in ipairs(Config.Recipes) do
        if QBCore.Shared.Items[r.item] then
            local info = itemInfo(r.item)
            local mats = {}
            for _, m in ipairs(recipeMats(r)) do
                local mi = itemInfo(m[1])
                mats[#mats + 1] = { item = m[1], label = mi.label, image = mi.image, need = m[2], have = have[m[1]] or 0, bp = m[3] }
            end
            recipes[#recipes + 1] = {
                idx = i, item = r.item, label = info.label, image = info.image, desc = info.desc,
                cat = r.cat, level = r.level, xp = r.xp, amount = r.amount or 1,
                time = craftTime(r, 1, lv), mats = mats,
            }
        end
    end
    local levels = {}
    for i = 0, Config.MaxLevel do levels[#levels + 1] = { xp = Config.Levels[i].xp, name = Config.Levels[i].name } end
    return {
        table = tbl and tbl.label or 'ورشة',
        name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        xp = xp, level = lv, levels = levels, speed = math.floor(math.min(0.6, lv * Config.SpeedPerLevel) * 100),
        maxQty = Config.MaxQty, categories = Config.Categories, recipes = recipes,
        busy = busy[src] and true or false,
    }
end

RegisterNetEvent('og_crafting:open', function()
    local src = source
    local tbl = nearTable(src)
    if not tbl then
        return TriggerClientEvent('QBCore:Notify', src, 'قرب أكثر على الطاولة', 'error')
    end
    local ok, data = pcall(payload, src, tbl)
    if not ok then
        print('^1[og_crafting] خطأ بفتح الطاولة: ' .. tostring(data) .. '^7')
        return TriggerClientEvent('QBCore:Notify', src, 'صار خطأ بالطاولة، شوف كونسول السيرفر', 'error')
    end
    if data then TriggerClientEvent('og_crafting:show', src, data) end
end)

-- ===================== التصنيع =====================
local function hasMats(Player, r, qty)
    local have = counts(Player)
    for _, m in ipairs(recipeMats(r)) do
        if (have[m[1]] or 0) < m[2] * qty then return false, m[1] end
    end
    return true
end

RegisterNetEvent('og_crafting:start', function(idx, qty)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local r = Config.Recipes[tonumber(idx) or 0]
    qty = math.floor(tonumber(qty) or 1)
    if not Player or not r or busy[src] then return end
    if qty < 1 or qty > Config.MaxQty then return end
    if not nearTable(src) then return end
    local lv = levelOf(getXp(Player))
    if lv < r.level then
        return TriggerClientEvent('QBCore:Notify', src, 'تحتاج مستوى ' .. r.level .. ' حتى تصنع هذا', 'error')
    end
    local ok, missing = hasMats(Player, r, qty)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, 'ناقصك: ' .. itemInfo(missing).label, 'error')
    end
    local ms = craftTime(r, qty, lv)
    busy[src] = { idx = tonumber(idx), qty = qty, ends = GetGameTimer() + ms - 600 }
    TriggerClientEvent('og_crafting:started', src, ms)
end)

RegisterNetEvent('og_crafting:cancel', function()
    busy[source] = nil
end)

RegisterNetEvent('og_crafting:finish', function()
    local src = source
    local b = busy[src]
    busy[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if not b or not Player then return end
    if GetGameTimer() < b.ends or not nearTable(src) then return end
    local r = Config.Recipes[b.idx]
    local qty = b.qty
    local out = (r.amount or 1) * qty

    local ok, missing = hasMats(Player, r, qty)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, 'ناقصك: ' .. itemInfo(missing).label, 'error')
    end

    local item = QBCore.Shared.Items[r.item]
    if not exports['qb-inventory']:CanAddItem(src, r.item, out) then
        TriggerClientEvent('QBCore:Notify', src, 'الحقيبة مليانة', 'error')
        return TriggerClientEvent('og_crafting:refresh', src)
    end

    for _, m in ipairs(recipeMats(r)) do
        exports['qb-inventory']:RemoveItem(src, m[1], m[2] * qty, false, 'og_crafting')
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[m[1]], 'remove', m[2] * qty)
    end
    if item.unique then
        for _ = 1, out do exports['qb-inventory']:AddItem(src, r.item, 1, false, false, 'og_crafting') end
    else
        exports['qb-inventory']:AddItem(src, r.item, out, false, false, 'og_crafting')
    end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, item, 'add', out)

    local before = getXp(Player)
    local after = before + r.xp * qty
    Player.Functions.SetMetaData(Config.MetaKey, after)
    local l1, l2 = levelOf(before), levelOf(after)
    TriggerClientEvent('og_crafting:done', src, { label = item.label, amount = out, xp = r.xp * qty, levelUp = l2 > l1 and l2 or nil, levelName = Config.Levels[l2].name })
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)

-- ===================== أوامر الأدمن =====================
QBCore.Commands.Add('setcraftlevel', 'تحديد مستوى التصنيع للاعب', { { name = 'id', help = 'رقم اللاعب' }, { name = 'level', help = '0 - 12' } }, true, function(src, args)
    local target = QBCore.Functions.GetPlayer(tonumber(args[1]) or -1)
    local lv = math.floor(tonumber(args[2]) or -1)
    if not target or not Config.Levels[lv] then
        return TriggerClientEvent('QBCore:Notify', src, 'رقم أو مستوى غلط', 'error')
    end
    target.Functions.SetMetaData(Config.MetaKey, Config.Levels[lv].xp)
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, 'صار مستوى التصنيع مالتك ' .. lv .. ' (' .. Config.Levels[lv].name .. ')', 'success')
    if src > 0 then TriggerClientEvent('QBCore:Notify', src, 'تم', 'success') end
end, 'admin')

exports('GetLevel', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and levelOf(getXp(Player)) or 0
end)

-- ===================== المخطوطات من السرقات =====================
-- تنعطى بالحظ لمن اللاعب ياخذ غنيمة من سرقة بيت أو محل (حسب Config.Blueprints.sources)
local bpCool = {}
local function pickBlueprint(cat)
    local pool, total = {}, 0
    for _, r in ipairs(Config.Recipes) do
        local bp = (not cat or r.cat == cat) and blueprintOf(r)
        if bp then
            local w = math.max(1, (Config.MaxLevel + 1) - r.level) ^ 2 -- الأسلحة القوية أندر
            pool[#pool + 1] = { bp, w }
            total = total + w
        end
    end
    local roll = math.random() * total
    for _, p in ipairs(pool) do
        roll = roll - p[2]
        if roll <= 0 then return p[1] end
    end
end

-- للسكربتات الثانية (مثل og_robberies): يرجع اسم مخطوطة عشوائية من قسم معين (مثلاً 'pistol')
exports('PickBlueprint', function(cat) return pickBlueprint(cat) end)

CreateThread(function()
    if not Config.Blueprints then return end
    while GetResourceState('qb-inventory') ~= 'started' do Wait(1000) end
    exports['qb-inventory']:AddListener('ItemAdded', function(_, data)
        if type(data) ~= 'table' or data.toType ~= 'player' then return end
        local chance = Config.Blueprints.sources[data.resource or '']
        local src = tonumber(data.toId)
        if not chance or not src then return end
        local key = src .. data.resource
        if bpCool[key] and os.time() - bpCool[key] < Config.Blueprints.cooldown then return end
        bpCool[key] = os.time()
        if math.random() > chance then return end
        local bp = pickBlueprint()
        if not bp then return end
        SetTimeout(500, function()
            if exports['qb-inventory']:AddItem(src, bp, 1, false, false, 'og_crafting:blueprint') then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[bp], 'add', 1)
                TriggerClientEvent('QBCore:Notify', src, 'لگيت ' .. QBCore.Shared.Items[bp].label .. '!', 'success', 7000)
            end
        end)
    end)
end)