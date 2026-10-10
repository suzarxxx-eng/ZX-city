local QBCore = exports['qb-core']:GetCoreObject()
local Inv = exports['qb-inventory']

local XP = {}       -- [citizenid] = { [job] = xp }
local Duty = {}     -- [src] = job
local Pending = {}  -- [src] = عملية جمع/معالجة شغالة

---------------------------------------------------------------- قاعدة البيانات
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `og_jobs_xp` (
            `citizenid` VARCHAR(50) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            `xp` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`, `job`)
        )
    ]])
end)

---------------------------------------------------------------- التوظيف (وظيفة واحدة فقط لكل لاعب)
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `og_jobs_employment` (
            `citizenid` VARCHAR(50) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

local Employed = {} -- [citizenid] = job أو false
local Sells = {}    -- [job] = مكان البيع المحدد بـ /jobsell

local function employmentOf(cid)
    if Employed[cid] ~= nil then return Employed[cid] or nil end
    local row = MySQL.single.await('SELECT job FROM og_jobs_employment WHERE citizenid = ?', { cid })
    Employed[cid] = row and row.job or false
    return row and row.job or nil
end

local function notify(src, msg, kind)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary')
end

local function getPlayer(src)
    return exports['qb-core']:GetPlayer(src)
end

local function loadXp(cid)
    if XP[cid] then return XP[cid] end
    local t = {}
    local rows = MySQL.query.await('SELECT job, xp FROM og_jobs_xp WHERE citizenid = ?', { cid }) or {}
    for _, r in ipairs(rows) do t[r.job] = r.xp end
    XP[cid] = t
    return t
end

local function levelOf(xp)
    local level = 1
    for i, need in ipairs(Config.Levels) do
        if xp >= need then level = i end
    end
    return level
end

local function nextNeed(level)
    return Config.Levels[level + 1]
end

local function getXp(cid, job)
    return loadXp(cid)[job] or 0
end

local function addXp(src, Player, job, amount)
    if not amount or amount <= 0 then return end
    local cid = Player.PlayerData.citizenid
    local t = loadXp(cid)
    local before = levelOf(t[job] or 0)
    t[job] = (t[job] or 0) + amount
    MySQL.update('INSERT INTO og_jobs_xp (citizenid, job, xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp)', { cid, job, t[job] })
    local after = levelOf(t[job])
    if after > before then
        notify(src, ('ترقيت! مستواك بـ %s صار %d'):format(Config.Jobs[job].label, after), 'success')
    end
end

local function multiplier(level)
    return 1.0 + (level - 1) * Config.PayBonusPerLevel
end

-- إجمالي الدخل لكل لاعب بكل وظيفة (يظهر بمركز التوظيف)
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `og_jobs_earned` (
            `citizenid` VARCHAR(50) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            `earned` BIGINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`, `job`)
        )
    ]])
end)

local Earned = {} -- [citizenid] = { [job] = total }

local function loadEarned(cid)
    if Earned[cid] then return Earned[cid] end
    local t = {}
    local rows = MySQL.query.await('SELECT job, earned FROM og_jobs_earned WHERE citizenid = ?', { cid }) or {}
    for _, r in ipairs(rows) do t[r.job] = r.earned end
    Earned[cid] = t
    return t
end

local function addEarned(cid, job, amount)
    local t = loadEarned(cid)
    t[job] = (t[job] or 0) + amount
    MySQL.update('INSERT INTO og_jobs_earned (citizenid, job, earned) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE earned = VALUES(earned)', { cid, job, t[job] })
end

local function pay(src, Player, job, amount)
    amount = math.floor(amount)
    if amount <= 0 then return 0 end
    Player.AddMoney(Config.PayAccount, amount, 'og_jobs-' .. job)
    addEarned(Player.PlayerData.citizenid, job, amount)
    return amount
end

---------------------------------------------------------------- تحقق
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end -- OneSync مطفي: ما نكدر نتحقق
    local c = GetEntityCoords(ped)
    return #(c - vector3(coords.x, coords.y, coords.z)) <= dist
end

local function stageOf(job, idx)
    local j = Config.Jobs[job]
    return j and j.stages and j.stages[tonumber(idx) or 0]
end

local function canCarry(src, item, amount)
    local ok = Inv:CanAddItem(src, item, amount)
    return ok and true or false
end

-- بعد أفقي فقط (ما يهمنا الارتفاع): نقاط البيع إحداثياتها الرأسية تقريبية
local function near2d(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end -- OneSync مطفي: ما نكدر نتحقق
    local c = GetEntityCoords(ped)
    local dx, dy = c.x - coords.x, c.y - coords.y
    return (dx * dx + dy * dy) <= dist * dist
end

-- نقطة بيع الوظيفة: /jobsell (sells.json) تغطي j.sell.coords من ملف الوظيفة. nil = البيع عند الباب
local function sellPoint(job)
    local s = Sells[job]
    if s and s.x and s.y then return s end
    local j = Config.Jobs[job]
    local c = j and j.sell and j.sell.coords
    return c and { x = c.x, y = c.y, z = c.z } or nil
end

-- واجهة مشتركة مع taxi_server.lua (نفس المورد، نفس الـ Lua)
OG = {
    Duty = Duty, getPlayer = getPlayer, notify = notify, near = near, employmentOf = employmentOf,
    getXp = getXp, levelOf = levelOf, nextNeed = nextNeed, addXp = addXp, addEarned = addEarned,
}

---------------------------------------------------------------- حالة الوظيفة
QBCore.Functions.CreateCallback('og_jobs:cb:state', function(src, cb, job)
    local Player = getPlayer(src)
    if not Player or not Config.Jobs[job] then return cb(nil) end
    local xp = getXp(Player.PlayerData.citizenid, job)
    local level = levelOf(xp)
    cb({ employed = employmentOf(Player.PlayerData.citizenid) == job, duty = Duty[src] == job, xp = xp, level = level, nextXp = nextNeed(level), bonus = math.floor((multiplier(level) - 1) * 100) })
end)

QBCore.Functions.CreateCallback('og_jobs:cb:employment', function(src, cb)
    local Player = getPlayer(src)
    if not Player then return cb(nil) end
    cb(employmentOf(Player.PlayerData.citizenid), Duty[src])
end)

-- بيانات واجهة مركز التوظيف: حالتك + خبرتك ودخلك بكل وظيفة + المتصدرين
QBCore.Functions.CreateCallback('og_jobs:cb:centerData', function(src, cb)
    local Player = getPlayer(src)
    if not Player or not near(src, Config.Center.coords, 15.0) then return cb(nil) end
    local cid = Player.PlayerData.citizenid
    local xps, earned = loadXp(cid), loadEarned(cid)
    local jobs = {}
    for name in pairs(Config.Jobs) do
        local xp = xps[name] or 0
        jobs[name] = { xp = xp, level = levelOf(xp), earned = earned[name] or 0 }
    end

    local gov
    local pj = Player.PlayerData.job
    if pj and pj.name and pj.name ~= 'unemployed' then gov = pj.label or pj.name end

    local board = {}
    local rows = MySQL.query.await('SELECT x.job, x.xp, p.charinfo FROM og_jobs_xp x JOIN players p ON p.citizenid = x.citizenid WHERE x.xp > 0 ORDER BY x.xp DESC LIMIT 30') or {}
    for _, r in ipairs(rows) do
        local j = Config.Jobs[r.job]
        if j and #board < 10 then
            local name = '—'
            local ok, ci = pcall(json.decode, r.charinfo or '')
            if ok and type(ci) == 'table' then name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) end
            board[#board + 1] = { name = name, job = j.label, level = levelOf(r.xp), xp = r.xp }
        end
    end

    cb({
        employed = employmentOf(cid), duty = Duty[src], gov = gov,
        levels = Config.Levels, bonusPerLevel = Config.PayBonusPerLevel,
        jobs = jobs, board = board,
    })
end)

-- التوظيف يلغي وظيفتك الحالية (عسكري، شرطة...) ورتبتها نهائياً وما ترجع
local function employ(src, Player, job, j)
    local cid = Player.PlayerData.citizenid
    local lost = false
    if Player.PlayerData.job and Player.PlayerData.job.name ~= 'unemployed' then
        Player.SetJob('unemployed')
        lost = true
    end
    Player.SetMetaData('jailjob', {}) -- حتى ما يرجعها السجن بعدين

    Employed[cid] = job
    MySQL.update('INSERT INTO og_jobs_employment (citizenid, job) VALUES (?, ?) ON DUPLICATE KEY UPDATE job = VALUES(job)', { cid, job })
    if OG.taxiAbort then OG.taxiAbort(src) end -- كان سائق تكسي بمشوار؟ يتحاسب ويتسكّر
    Duty[src], Pending[src] = nil, nil
    TriggerClientEvent('og_jobs:client:reset', src)
    TriggerClientEvent('og_jobs:client:duty', src, nil)
    TriggerClientEvent('og_jobs:client:employment', src, job)
    notify(src, ('تم توظيفك بـ %s%s'):format(j.label, lost and ' • وفقدت وظيفتك السابقة ورتبتها نهائياً' or ''), 'success')
end

-- التقديم: يصير من مركز التوظيف فقط (من الواجهة)
QBCore.Functions.CreateCallback('og_jobs:cb:apply', function(src, cb, job)
    local Player = getPlayer(src)
    local j = type(job) == 'string' and Config.Jobs[job] or nil
    if not Player or not j then return cb(false) end
    if not near(src, Config.Center.coords, 12.0) then return cb(false, 'لازم تكون عند موظف مركز التوظيف') end
    if employmentOf(Player.PlayerData.citizenid) == job then return cb(false, 'أنت موظف بهذي الوظيفة من قبل') end
    employ(src, Player, job, j)
    cb(true)
end)

local function quitJob(src, Player)
    local cid = Player.PlayerData.citizenid
    Employed[cid] = false
    MySQL.update('DELETE FROM og_jobs_employment WHERE citizenid = ?', { cid })
    if OG.taxiAbort then OG.taxiAbort(src) end
    Duty[src], Pending[src] = nil, nil
    TriggerClientEvent('og_jobs:client:reset', src)
    TriggerClientEvent('og_jobs:client:duty', src, nil)
    TriggerClientEvent('og_jobs:client:employment', src, nil)
    notify(src, 'استقلت من الوظيفة', 'primary')
end

RegisterNetEvent('og_jobs:server:quit', function(job)
    local src = source
    local Player = getPlayer(src)
    if not Player or employmentOf(Player.PlayerData.citizenid) ~= job then return end
    quitJob(src, Player)
end)

QBCore.Functions.CreateCallback('og_jobs:cb:quit', function(src, cb)
    local Player = getPlayer(src)
    if not Player or not employmentOf(Player.PlayerData.citizenid) then return cb(false, 'ما عندك وظيفة') end
    quitJob(src, Player)
    cb(true)
end)

RegisterNetEvent('og_jobs:server:duty', function(job, state)
    local src = source
    local Player = getPlayer(src)
    local j = Config.Jobs[job]
    if not Player or not j then return end
    if not near(src, j.boss.coords, 12.0) then return end
    if state and employmentOf(Player.PlayerData.citizenid) ~= job then
        return notify(src, 'لازم تتوظف بهذي الوظيفة من مركز التوظيف أول', 'error')
    end
    if state then
        Duty[src] = job
        notify(src, 'بدأت دوامك: ' .. j.label, 'success')
    else
        if OG.taxiAbort then OG.taxiAbort(src) end
        if Duty[src] == job then Duty[src] = nil end
        Pending[src] = nil
        TriggerClientEvent('og_jobs:client:reset', src)
        notify(src, 'أنهيت دوامك', 'primary')
    end
    TriggerClientEvent('og_jobs:client:duty', src, Duty[src])
end)

RegisterNetEvent('og_jobs:server:buyTool', function(job, item)
    local src = source
    local Player = getPlayer(src)
    local j = Config.Jobs[job]
    if not Player or not j or not near(src, j.boss.coords, 12.0) then return end
    for _, tool in ipairs(j.tools or {}) do
        if tool.item == item then
            if Inv:GetItemCount(src, item) > 0 then return notify(src, 'عندك ' .. tool.label .. ' من قبل', 'error') end
            if not canCarry(src, item, 1) then return notify(src, 'حقيبتك ما تتحمل', 'error') end
            local paid = false
            if (Player.GetMoney('cash') or 0) >= tool.price then
                paid = Player.RemoveMoney('cash', tool.price, 'og_jobs-tool')
            elseif (Player.GetMoney('bank') or 0) >= tool.price then
                paid = Player.RemoveMoney('bank', tool.price, 'og_jobs-tool')
            end
            if not paid then return notify(src, ('ما عندك فلوس كافية ($%d)'):format(tool.price), 'error') end
            Inv:AddItem(src, item, 1, false, false, 'og_jobs:buyTool')
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
            return notify(src, ('اشتريت %s بـ $%d'):format(tool.label, tool.price), 'success')
        end
    end
end)

---------------------------------------------------------------- جمع ومعالجة
QBCore.Functions.CreateCallback('og_jobs:cb:begin', function(src, cb, job, stageIdx, pointIdx)
    local Player = getPlayer(src)
    local stage = stageOf(job, stageIdx)
    if not Player or not stage or Duty[src] ~= job then return cb(false, 'لازم تبدأ الدوام أول') end
    if stage.type ~= 'gather' and stage.type ~= 'process' then return cb(false) end
    if Pending[src] then return cb(false, 'عندك عملية شغالة') end

    local level = levelOf(getXp(Player.PlayerData.citizenid, job))
    if level < (stage.minLevel or 1) then
        return cb(false, ('تحتاج مستوى %d'):format(stage.minLevel))
    end
    -- أدوات متدرجة: أفضل أداة تملكها من القائمة تحدد وقت الحفر والكمية
    local usedTool, stageTime
    if stage.tiers then
        local order = { 'advanced_drill', 'mining_drill', 'pickaxe' }
        for _, name in ipairs(stage.tiers and (stage.toolOrder or order) or order) do
            if stage.tiers[name] and Inv:GetItemCount(src, name) > 0 then usedTool = name break end
        end
        if not usedTool then
            local labels = {}
            for name in pairs(stage.tiers) do labels[#labels + 1] = QBCore.Shared.Items[name] and QBCore.Shared.Items[name].label or name end
            return cb(false, 'تحتاج أداة: ' .. table.concat(labels, ' أو '))
        end
        stageTime = stage.tiers[usedTool].time
    elseif stage.requireItem and Inv:GetItemCount(src, stage.requireItem) < 1 then
        return cb(false, 'تحتاج ' .. (QBCore.Shared.Items[stage.requireItem] and QBCore.Shared.Items[stage.requireItem].label or stage.requireItem))
    end

    if stage.type == 'gather' then
        local point = stage.points[tonumber(pointIdx) or 0]
        if not point or not near(src, point.coords, (point.radius or 5.0) + 6.0) then return cb(false) end
        if not canCarry(src, stage.give.item, (stage.give.max or 1) + 3) then return cb(false, 'حقيبتك ممتلئة') end
    else
        local c = stage.station.coords
        if not near(src, c, 8.0) then return cb(false) end
        if Inv:GetItemCount(src, stage.take.item) < stage.take.amount then
            local it = QBCore.Shared.Items[stage.take.item]
            return cb(false, ('تحتاج %d × %s'):format(stage.take.amount, it and it.label or stage.take.item))
        end
    end

    stageTime = stageTime or stage.time or 5000
    Pending[src] = { job = job, stage = tonumber(stageIdx), startedAt = GetGameTimer(), time = stageTime, tool = usedTool }
    cb(true, nil, stageTime)
end)

RegisterNetEvent('og_jobs:server:cancel', function()
    Pending[source] = nil
end)

RegisterNetEvent('og_jobs:server:finish', function(job, stageIdx)
    local src = source
    local Player = getPlayer(src)
    local p = Pending[src]
    Pending[src] = nil
    local stage = stageOf(job, stageIdx)
    if not Player or not p or not stage or p.job ~= job or p.stage ~= tonumber(stageIdx) or Duty[src] ~= job then return end
    if GetGameTimer() - p.startedAt < p.time * Config.MinTimeRatio then return end -- أسرع من اللازم

    if stage.type == 'gather' then
        local amount = math.random(stage.give.min or 1, stage.give.max or 1)
        if p.tool and stage.tiers and stage.tiers[p.tool] then amount = amount + (stage.tiers[p.tool].bonus or 0) end
        if not canCarry(src, stage.give.item, amount) then return notify(src, 'حقيبتك ممتلئة', 'error') end
        if Inv:AddItem(src, stage.give.item, amount, false, false, 'og_jobs:gather') then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[stage.give.item], 'add', amount)
            addXp(src, Player, job, stage.xp)
        end
    else
        if Inv:GetItemCount(src, stage.take.item) < stage.take.amount then return end
        if not Inv:RemoveItem(src, stage.take.item, stage.take.amount, false, 'og_jobs:process') then return end
        if Inv:AddItem(src, stage.give.item, stage.give.amount, false, false, 'og_jobs:process') then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[stage.take.item], 'remove', stage.take.amount)
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[stage.give.item], 'add', stage.give.amount)
            addXp(src, Player, job, stage.xp)
        else
            Inv:AddItem(src, stage.take.item, stage.take.amount, false, false, 'og_jobs:refund') -- رجّع اللي انسحب
            notify(src, 'حقيبتك ممتلئة', 'error')
        end
    end
end)

---------------------------------------------------------------- بيع
-- قائمة اللي تكدر تبيعه (تظهر بقائمة E): كل غرض عندك مع الكمية والسعر
QBCore.Functions.CreateCallback('og_jobs:cb:sellList', function(src, cb, job)
    local Player = getPlayer(src)
    local j = Config.Jobs[job]
    if not Player or not j or Duty[src] ~= job then return cb(nil) end
    local sp = sellPoint(job)
    if sp and not near2d(src, sp, 14.0) then return cb(nil) end
    local mult = multiplier(levelOf(getXp(Player.PlayerData.citizenid, job)))
    local list = {}
    for idx, stage in ipairs(j.stages or {}) do
        if stage.type == 'sell' then
            for item, price in pairs(stage.prices or {}) do
                local have = Inv:GetItemCount(src, item)
                if have > 0 then
                    local it = QBCore.Shared.Items[item]
                    list[#list + 1] = {
                        stage = idx, item = item, label = it and it.label or item, count = have, price = math.floor(price * mult),
                        image = it and it.image or (item .. '.png'), alt = Config.ItemImages and Config.ItemImages[item],
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.price > b.price end)
    cb(list)
end)

RegisterNetEvent('og_jobs:server:sell', function(job, stageIdx, only)
    local src = source
    local Player = getPlayer(src)
    local stage = stageOf(job, stageIdx)
    local j = Config.Jobs[job]
    if not Player or not stage or stage.type ~= 'sell' or Duty[src] ~= job then return end
    local sp = sellPoint(job)
    if sp then
        if not near2d(src, sp, 14.0) then return notify(src, 'روح لنقطة البيع الخاصة بالوظيفة (شوف الأيقونة على الخريطة)', 'error') end
    else
        local where = (stage.station and stage.station.coords) or j.boss.coords
        if not near(src, where, 12.0) then return end
    end

    local level = levelOf(getXp(Player.PlayerData.citizenid, job))
    local total, count = 0, 0
    for item, price in pairs(stage.prices) do
        local have = (only == nil or only == item) and Inv:GetItemCount(src, item) or 0 -- only = غرض واحد من القائمة
        if have > 0 and Inv:RemoveItem(src, item, have, false, 'og_jobs:sell') then
            total = total + have * price
            count = count + have
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove', have)
        end
    end
    if count == 0 then return notify(src, 'ماعندك شي تبيعه هنا', 'error') end
    local paid = pay(src, Player, job, total * multiplier(level))
    addXp(src, Player, job, math.max(1, math.floor(count / 5)))
    notify(src, ('بعت %d غرض واستلمت $%d'):format(count, paid), 'success')
end)


-- أماكن أبواب الشركات: تتحدد باللعبة (/jobdoor) وتنحفظ بملف doors.json فوق إعدادات الوظائف
local Doors = {}
do
    local raw = LoadResourceFile(GetCurrentResourceName(), 'doors.json')
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then Doors = t end
    end
    for job, c in pairs(Doors) do
        if Config.Jobs[job] then Config.Jobs[job].boss.coords = vector4(c.x, c.y, c.z, c.w) end
    end
end

-- أيقونات الوظائف (/jobblip): تتخزن بملف jobblips.json وتظهر بعد تسجيل الدخول فقط
local JobBlips = {}
do
    local raw = LoadResourceFile(GetCurrentResourceName(), 'jobblips.json')
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then JobBlips = t end
    end
end

-- أماكن البيع (/jobsell): تتخزن بملف sells.json
do
    local raw = LoadResourceFile(GetCurrentResourceName(), 'sells.json')
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then Sells = t end
    end
end

-- مكان مركز التوظيف (/jobcenter): يتخزن بملف center.json فوق Config.Center
local CenterSaved
do
    local raw = LoadResourceFile(GetCurrentResourceName(), 'center.json')
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' and t.x and t.y and t.z and t.w then
            CenterSaved = t
            Config.Center.coords = vector4(t.x, t.y, t.z, t.w)
        end
    end
end

QBCore.Functions.CreateCallback('og_jobs:cb:doors', function(_, cb)
    cb({ doors = Doors, sells = Sells, blips = JobBlips, center = CenterSaved })
end)

-- /jobcenter: قف بمكان موظف مركز التوظيف الجديد واكتب الأمر (للأدمن)
QBCore.Commands.Add('jobcenter', 'نقل موظف مركز التوظيف لمكانك الحالي', {}, false, function(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return notify(source, 'ما كدرت أقرا مكانك (OneSync)', 'error') end
    local c = GetEntityCoords(ped)
    CenterSaved = { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
    SaveResourceFile(GetCurrentResourceName(), 'center.json', json.encode(CenterSaved), -1)
    Config.Center.coords = vector4(CenterSaved.x, CenterSaved.y, CenterSaved.z, CenterSaved.w)
    TriggerClientEvent('og_jobs:client:centerUpdated', -1, CenterSaved)
    notify(source, 'تم نقل مركز التوظيف لمكانك', 'success')
end, 'admin')

local function findJob(query)
    if not query or query == '' then return nil end
    for name, j in pairs(Config.Jobs) do
        if name == query or j.label == query or j.label:find(query, 1, true) == 1 then return name end
    end
end

-- /jobdoor <الوظيفة>: قف قدام باب الشركة واكتب الأمر، يصير هذا مكان تسجيل الدخول بالعين (للأدمن)
QBCore.Commands.Add('jobdoor', 'تحديد باب شركة وظيفة بمكانك الحالي (مثال: /jobdoor تكسي)', { { name = 'الوظيفة', help = 'اسم الوظيفة بالعربي' } }, false, function(source, args)
    local job = findJob(table.concat(args, ' '))
    if not job then
        local names = {}
        for _, j in pairs(Config.Jobs) do names[#names + 1] = j.label end
        return notify(source, 'اكتب اسم الوظيفة: ' .. table.concat(names, ' - '), 'error')
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return notify(source, 'ما كدرت أقرا مكانك (OneSync)', 'error') end
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    Doors[job] = { x = c.x, y = c.y, z = c.z - 1.0, w = h }
    SaveResourceFile(GetCurrentResourceName(), 'doors.json', json.encode(Doors), -1)
    Config.Jobs[job].boss.coords = vector4(c.x, c.y, c.z - 1.0, h)
    TriggerClientEvent('og_jobs:client:doorUpdated', -1, job, Doors[job])
    notify(source, ('تم تحديد باب %s بمكانك'):format(Config.Jobs[job].label), 'success')
end, 'admin')

-- /jobsell <الوظيفة>: قف بمكان البيع واكتب الأمر، يصير هذا مكان بيع الوظيفة بالعين (للأدمن)
QBCore.Commands.Add('jobsell', 'تحديد مكان بيع وظيفة بمكانك الحالي (مثال: /jobsell التنقيب)', { { name = 'الوظيفة', help = 'اسم الوظيفة بالعربي' } }, false, function(source, args)
    local job = findJob(table.concat(args, ' '))
    if not job then
        local names = {}
        for _, j in pairs(Config.Jobs) do names[#names + 1] = j.label end
        return notify(source, 'اكتب اسم الوظيفة: ' .. table.concat(names, ' - '), 'error')
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return notify(source, 'ما كدرت أقرا مكانك (OneSync)', 'error') end
    local c = GetEntityCoords(ped)
    Sells[job] = { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
    SaveResourceFile(GetCurrentResourceName(), 'sells.json', json.encode(Sells), -1)
    TriggerClientEvent('og_jobs:client:sellUpdated', -1, job, Sells[job])
    notify(source, ('تم تحديد مكان بيع %s بمكانك'):format(Config.Jobs[job].label), 'success')
end, 'admin')
-- /jobblip <الوظيفة> <الشكل> <اللون> <الاسم>: يضيف أيقونة وظيفة بمكانك (تظهر بعد تسجيل الدخول فقط)
-- مثال: /jobblip التنقيب 527 5 محجر التنقيب
QBCore.Commands.Add('jobblip', 'إضافة أيقونة وظيفة بمكانك: /jobblip الوظيفة الشكل اللون الاسم', {
    { name = 'الوظيفة', help = 'مثلاً التنقيب' },
    { name = 'الشكل', help = 'رقم الأيقونة (شوف ملف الاشكال_والالوان)' },
    { name = 'اللون', help = 'رقم اللون' },
    { name = 'الاسم', help = 'اسم الأيقونة' },
}, false, function(source, args)
    local job = findJob(args[1])
    local sprite, color = tonumber(args[2]), tonumber(args[3])
    if not job or not sprite or not color or #args < 4 then
        return notify(source, 'الصيغة: /jobblip التنقيب 527 5 اسم الأيقونة', 'error')
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return notify(source, 'ما كدرت أقرا مكانك (OneSync)', 'error') end
    local c = GetEntityCoords(ped)
    JobBlips[job] = JobBlips[job] or {}
    JobBlips[job][#JobBlips[job] + 1] = { x = c.x, y = c.y, z = c.z, sprite = sprite, color = color, label = table.concat(args, ' ', 4) }
    SaveResourceFile(GetCurrentResourceName(), 'jobblips.json', json.encode(JobBlips), -1)
    TriggerClientEvent('og_jobs:client:blipsUpdated', -1, job, JobBlips[job])
    notify(source, ('أضفت أيقونة لـ %s (تظهر بعد تسجيل الدخول)'):format(Config.Jobs[job].label), 'success')
end, 'admin')

-- /jobblipundo <الوظيفة>: يحذف آخر أيقونة أضفتها للوظيفة
QBCore.Commands.Add('jobblipundo', 'حذف آخر أيقونة أضفتها لوظيفة', { { name = 'الوظيفة', help = 'مثلاً التنقيب' } }, false, function(source, args)
    local job = findJob(args[1])
    if not job or not JobBlips[job] or #JobBlips[job] == 0 then return notify(source, 'ماكو أيقونات مضافة لهذي الوظيفة', 'error') end
    local removed = table.remove(JobBlips[job])
    SaveResourceFile(GetCurrentResourceName(), 'jobblips.json', json.encode(JobBlips), -1)
    TriggerClientEvent('og_jobs:client:blipsUpdated', -1, job, JobBlips[job])
    notify(source, ('انحذفت: %s'):format(removed.label), 'success')
end, 'admin')
-- /jobtp <اسم الوظيفة>: ينقلك لموظف الوظيفة (للأدمن). بدون اسم يطبع قائمة الوظائف.
QBCore.Commands.Add('jobtp', 'انتقال لموظف وظيفة (مثال: /jobtp تكسي)', { { name = 'الوظيفة', help = 'اسم الوظيفة بالعربي' } }, false, function(source, args)
    local query = table.concat(args, ' ')
    local found
    if query ~= '' then
        for name, j in pairs(Config.Jobs) do
            -- نقبل الاسم الكامل أو أول جزء منه، أو الاسم الإنكليزي القديم
            if name == query or j.label == query or j.label:find(query, 1, true) == 1 then found = name break end
        end
    end
    if found then
        TriggerClientEvent('og_jobs:client:tp', source, found)
    else
        local names = {}
        for _, j in pairs(Config.Jobs) do names[#names + 1] = j.label end
        notify(source, 'الوظائف: ' .. table.concat(names, ' - '))
    end
end, 'admin')

AddEventHandler('playerDropped', function()
    local src = source
    Duty[src], Pending[src] = nil, nil
end)
