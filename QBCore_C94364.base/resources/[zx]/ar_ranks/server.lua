local QBCore = exports['qb-core']:GetCoreObject()

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary', 5000)
end

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return {} end
    local ok, res = pcall(json.decode, v)
    return ok and res or {}
end

local function jobInfo(jobName)
    return QBCore.Shared.Jobs[jobName]
end

local function gradeOf(jobName, level)
    local job = jobInfo(jobName)
    return job and job.grades[tostring(level)]
end

local function maxGrade(jobName)
    local job, top = jobInfo(jobName), 0
    if not job then return 0 end
    for k in pairs(job.grades) do
        local n = tonumber(k)
        if n and n > top then top = n end
    end
    return top
end

local function fullName(charinfo)
    charinfo = decode(charinfo)
    local n = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or 'مجهول'
end

-- صلاحيات اللاعب على وظيفته
local function perms(Player)
    local job = Player.PlayerData.job
    local level = tonumber(job.grade.level) or 0
    local top = maxGrade(job.name)
    local isBoss = job.isboss == true
    return {
        level = level,
        top = top,
        manage = level >= Config.ManageFrom,
        hire = isBoss or (not Config.BossOnlyHireFire and level >= Config.ManageFrom),
    }
end

-- الأعلى رتبة يكدر يشتغل على اللي تحته بس، ويرفع لحد رتبة تحت رتبته
-- (صاحب أعلى رتبة يكدر يرفع لحد رتبته)
local function canSet(p, targetLevel, newLevel)
    if not p.manage then return false end
    if targetLevel >= p.level then return false end
    if newLevel < 0 then return false end
    if p.level >= p.top then return newLevel <= p.top end
    return newLevel < p.level
end

local function buildData(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local job = Player.PlayerData.job
    if not Config.Jobs[job.name] then return nil end
    local info = jobInfo(job.name)
    if not info then return nil end
    local p = perms(Player)

    local grades = {}
    for k, g in pairs(info.grades) do
        local lvl = tonumber(k)
        if lvl then
            grades[#grades + 1] = { level = lvl, name = g.name, payment = g.payment or 0, isboss = g.isboss == true, count = 0 }
        end
    end
    table.sort(grades, function(a, b) return a.level < b.level end)
    local byLevel = {}
    for _, g in ipairs(grades) do byLevel[g.level] = g end

    -- المنتسبين: المتصلين من الذاكرة، والباقين من الداتابيس
    local members, seen = {}, {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local pd = v.PlayerData
        if pd.job.name == job.name then
            local lvl = tonumber(pd.job.grade.level) or 0
            seen[pd.citizenid] = true
            members[#members + 1] = {
                cid = pd.citizenid, id = pd.source, online = true, onduty = pd.job.onduty == true,
                name = fullName(pd.charinfo), level = lvl, callsign = pd.metadata and pd.metadata.callsign or nil,
            }
        end
    end
    local rows = MySQL.query.await("SELECT citizenid, charinfo, job, metadata FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?", { job.name }) or {}
    for _, r in ipairs(rows) do
        if not seen[r.citizenid] then
            local j, md = decode(r.job), decode(r.metadata)
            members[#members + 1] = {
                cid = r.citizenid, online = false, onduty = false, name = fullName(r.charinfo),
                level = tonumber(j.grade and j.grade.level) or 0, callsign = md.callsign,
            }
        end
    end

    for _, m in ipairs(members) do
        local g = byLevel[m.level]
        m.rank = g and g.name or ('رتبة ' .. m.level)
        if g then g.count = g.count + 1 end
        if m.callsign == 'NO CALLSIGN' or m.callsign == '' then m.callsign = nil end
        m.me = m.cid == Player.PlayerData.citizenid
        m.editable = canSet(p, m.level, m.level - 1) or canSet(p, m.level, m.level)
    end
    table.sort(members, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)

    -- مفاتيح نصية حتى تنقرى صح بالواجهة (الرقم 0 يضيع إذا انقلبت مصفوفة)
    local insignia = {}
    for k, v in pairs(Config.Insignia) do insignia[tostring(k)] = v end

    local myGrade = byLevel[p.level]
    return {
        job = info.label or job.name,
        me = { level = p.level, rank = myGrade and myGrade.name or '', name = fullName(Player.PlayerData.charinfo) },
        perms = { manage = p.manage, hire = p.hire, top = p.top, level = p.level },
        grades = grades,
        members = members,
        insignia = insignia,
        groups = Config.Groups,
    }
end

-- يغير رتبة منتسب (متصل أو لا)
local function applyGrade(jobName, cid, newLevel)
    local Target = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Target then
        if Target.PlayerData.job.name ~= jobName then return false end
        return Target.Functions.SetJob(jobName, newLevel), Target
    end
    local row = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', { cid })
    if not row then return false end
    local j = decode(row.job)
    if j.name ~= jobName then return false end
    local info, g = jobInfo(jobName), gradeOf(jobName, newLevel)
    if not g then return false end
    j.label = info.label
    j.type = info.type
    j.payment = g.payment or 0
    j.isboss = g.isboss == true
    j.onduty = false
    j.grade = { name = g.name, level = newLevel }
    MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(j), cid })
    return true
end

local function targetLevel(jobName, cid)
    local Target = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Target then
        if Target.PlayerData.job.name ~= jobName then return nil end
        return tonumber(Target.PlayerData.job.grade.level) or 0, fullName(Target.PlayerData.charinfo), Target
    end
    local row = MySQL.single.await('SELECT job, charinfo FROM players WHERE citizenid = ?', { cid })
    if not row then return nil end
    local j = decode(row.job)
    if j.name ~= jobName then return nil end
    return tonumber(j.grade and j.grade.level) or 0, fullName(row.charinfo)
end

local function announce(jobName, text, exceptSrc)
    if not Config.AnnouncePromotions then return end
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == jobName and v.PlayerData.source ~= exceptSrc then
            notify(v.PlayerData.source, text, 'primary')
        end
    end
end

QBCore.Functions.CreateCallback('ar_ranks:getData', function(src, cb)
    cb(buildData(src))
end)

QBCore.Functions.CreateCallback('ar_ranks:action', function(src, cb, act)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(act) ~= 'table' then return cb({ ok = false }) end
    local jobName = Player.PlayerData.job.name
    if not Config.Jobs[jobName] then return cb({ ok = false, msg = 'ما عندك صلاحية' }) end
    local p = perms(Player)
    local myName = fullName(Player.PlayerData.charinfo)
    local myRank = (gradeOf(jobName, p.level) or {}).name or ''

    local function done(ok, msg)
        cb({ ok = ok, msg = msg, data = buildData(src) })
    end

    if act.type == 'grade' then
        local cid, newLevel = tostring(act.cid or ''), math.floor(tonumber(act.level) or -1)
        local cur, name, Target = targetLevel(jobName, cid)
        if not cur then return done(false, 'المنتسب مو موجود بالوظيفة') end
        local g = gradeOf(jobName, newLevel)
        if not g then return done(false, 'الرتبة مو موجودة') end
        if newLevel == cur then return done(false, 'هو أصلاً بهاي الرتبة') end
        if not canSet(p, cur, newLevel) then return done(false, 'ما تكدر تغير هاي الرتبة') end
        if not applyGrade(jobName, cid, newLevel) then return done(false, 'صار خطأ، جرب مرة ثانية') end

        local up = newLevel > cur
        if Target then
            TriggerClientEvent('ar_ranks:client:changed', Target.PlayerData.source, { up = up, rank = g.name, level = newLevel, by = myRank .. ' ' .. myName, insignia = Config.Insignia[newLevel] })
        end
        if up then announce(jobName, ('تمت ترقية %s إلى رتبة %s'):format(name, g.name), Target and Target.PlayerData.source) end
        print(('[ar_ranks] %s (%s) %s %s -> %s'):format(myName, src, up and 'رفّع' or 'نزّل', name, g.name))
        return done(true, ('%s %s إلى %s'):format(up and 'تمت ترقية' or 'تم تنزيل', name, g.name))

    elseif act.type == 'fire' then
        if not p.hire then return done(false, 'الفصل بس للقيادة') end
        local cid = tostring(act.cid or '')
        local cur, name, Target = targetLevel(jobName, cid)
        if not cur then return done(false, 'المنتسب مو موجود بالوظيفة') end
        if cur >= p.level then return done(false, 'ما تكدر تفصل رتبة مثلك أو أعلى') end
        if Target then
            Target.Functions.SetJob('unemployed', 0)
            notify(Target.PlayerData.source, 'تم فصلك من ' .. (jobInfo(jobName).label or jobName), 'error')
        else
            local u = jobInfo('unemployed')
            local ug = u.grades['0']
            MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode({
                name = 'unemployed', label = u.label, payment = ug.payment or 0, type = u.type, onduty = true, isboss = false,
                grade = { name = ug.name, level = 0 },
            }), cid })
        end
        print(('[ar_ranks] %s (%s) فصل %s'):format(myName, src, name))
        return done(true, 'تم فصل ' .. name)

    elseif act.type == 'hire' then
        if not p.hire then return done(false, 'التعيين بس للقيادة') end
        local tid = tonumber(act.id)
        local Target = tid and QBCore.Functions.GetPlayer(tid)
        if not Target then return done(false, 'ماكو لاعب متصل بهذا الرقم') end
        if Target.PlayerData.job.name == jobName then return done(false, 'هو أصلاً منتسب') end
        Target.Functions.SetJob(jobName, 0)
        local g = gradeOf(jobName, 0)
        local name = fullName(Target.PlayerData.charinfo)
        TriggerClientEvent('ar_ranks:client:changed', tid, { up = true, hired = true, rank = g and g.name or '', level = 0, by = myRank .. ' ' .. myName, insignia = Config.Insignia[0] })
        announce(jobName, ('انضم %s إلى %s'):format(name, jobInfo(jobName).label or jobName), tid)
        print(('[ar_ranks] %s (%s) عيّن %s'):format(myName, src, name))
        return done(true, 'تم تعيين ' .. name)
    end

    cb({ ok = false })
end)
