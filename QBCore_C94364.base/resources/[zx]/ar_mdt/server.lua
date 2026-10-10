local QBCore = exports['qb-core']:GetCoreObject()
local Status = {}  -- [citizenid] = 'available' ...

------------------------------------------------------------------
-- الجداول (تنسوى وحدها أول تشغيل)
------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_profiles` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `image` TEXT NULL, `notes` TEXT NULL, `tags` TEXT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_reports` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(150) NOT NULL, `type` VARCHAR(60) NULL, `body` TEXT NULL,
        `involved` TEXT NULL, `officers` TEXT NULL,
        `author` VARCHAR(120) NULL, `author_cid` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_warrants` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(120) NULL,
        `reason` TEXT NULL, `charges` TEXT NULL,
        `author` VARCHAR(120) NULL, `active` TINYINT NOT NULL DEFAULT 1,
        `closed_by` VARCHAR(120) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY `citizenid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_bolos` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(20) NOT NULL DEFAULT 'person', `title` VARCHAR(150) NOT NULL,
        `plate` VARCHAR(20) NULL, `description` TEXT NULL,
        `author` VARCHAR(120) NULL, `active` TINYINT NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_vehicles` (
        `plate` VARCHAR(20) NOT NULL PRIMARY KEY,
        `stolen` TINYINT NOT NULL DEFAULT 0, `notes` TEXT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ar_mdt_convictions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `charges` TEXT NULL,
        `fine` INT NOT NULL DEFAULT 0, `jail` INT NOT NULL DEFAULT 0,
        `fined` TINYINT NOT NULL DEFAULT 0, `jailed` TINYINT NOT NULL DEFAULT 0,
        `note` TEXT NULL, `author` VARCHAR(120) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY `citizenid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
    -- أعمدة القضايا (اسم المتهم + شنو سوا)
    MySQL.query.await('ALTER TABLE `ar_mdt_convictions` ADD COLUMN IF NOT EXISTS `name` VARCHAR(120) NULL AFTER `citizenid`')
    MySQL.query.await('ALTER TABLE `ar_mdt_convictions` ADD COLUMN IF NOT EXISTS `description` TEXT NULL AFTER `note`')
end)

------------------------------------------------------------------
-- مساعدات
------------------------------------------------------------------
local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return {} end
    local ok, r = pcall(json.decode, v)
    return (ok and type(r) == 'table') and r or {}
end

local function str(v, max)
    v = tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #v > max then
        v = v:sub(1, max):gsub('[\192-\255][\128-\191]*$', '') -- لا نكسر حرف عربي بالنص
    end
    return v
end

local function fullName(ci)
    ci = decode(ci)
    local n = str((ci.firstname or '') .. ' ' .. (ci.lastname or ''))
    return n ~= '' and n or 'مجهول'
end

local function like(q) return '%' .. q:gsub('[%%_\\]', '\\%0') .. '%' end

local PenalById = {}
for _, cat in ipairs(Config.Penal) do
    for _, it in ipairs(cat.items) do PenalById[it.id] = it end
end

local VehLabels = {}
CreateThread(function()
    for k, v in pairs(QBCore.Shared.Vehicles or {}) do
        VehLabels[k] = ((v.brand or '') .. ' ' .. (v.name or k)):gsub('^%s+', '')
    end
end)

-- الضابط اللي فاتح الـ MDT
local function officer(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local job = P.PlayerData.job
    if not Config.Jobs[job.name] then return nil end
    if Config.NeedDuty and not job.onduty then return nil end
    local cs = P.PlayerData.metadata.callsign
    if cs == 'NO CALLSIGN' then cs = nil end
    return {
        P = P, src = src, cid = P.PlayerData.citizenid,
        name = fullName(P.PlayerData.charinfo), rank = job.grade.name or '', level = tonumber(job.grade.level) or 0,
        callsign = cs, job = job.label or job.name,
        canDelete = (tonumber(job.grade.level) or 0) >= Config.DeleteGrade or job.isboss == true,
        sign = (job.grade.name or '') .. ' ' .. fullName(P.PlayerData.charinfo),
    }
end

local function notifyOfficers(msg, typ)
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local j = v.PlayerData.job
        if Config.Jobs[j.name] and j.onduty then
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, msg, typ or 'primary', 7000)
        end
    end
end

local function units()
    local list = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local pd = v.PlayerData
        if Config.Jobs[pd.job.name] and pd.job.onduty then
            local cs = pd.metadata.callsign
            list[#list + 1] = {
                id = pd.source, cid = pd.citizenid, name = fullName(pd.charinfo),
                rank = pd.job.grade.name or '', level = tonumber(pd.job.grade.level) or 0,
                job = pd.job.label, callsign = (cs ~= 'NO CALLSIGN' and cs) or nil,
                status = Status[pd.citizenid] or 'available',
                role = GetResourceState('ar_ops') == 'started' and exports['ar_ops']:GetRole(pd.source) or nil,
            }
        end
    end
    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end

------------------------------------------------------------------
-- الأوامر من الواجهة
------------------------------------------------------------------
local H = {}

function H.init(o)
    return {
        me = { name = o.name, rank = o.rank, callsign = o.callsign, cid = o.cid, job = o.job, canDelete = o.canDelete, status = Status[o.cid] or 'available' },
        penal = Config.Penal, statuses = Config.Statuses, licenses = Config.Licenses,
        tags = Config.Tags, reportTypes = Config.ReportTypes,
    }
end

function H.dashboard()
    local c = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM ar_mdt_warrants WHERE active = 1) AS warrants,
        (SELECT COUNT(*) FROM ar_mdt_bolos WHERE active = 1) AS bolos,
        (SELECT COUNT(*) FROM ar_mdt_reports WHERE created_at >= NOW() - INTERVAL 1 DAY) AS reports,
        (SELECT COUNT(*) FROM ar_mdt_convictions WHERE created_at >= NOW() - INTERVAL 1 DAY) AS convictions]]) or {}
    local u = units()
    return {
        counts = { units = #u, warrants = c.warrants or 0, bolos = c.bolos or 0, reports = c.reports or 0, convictions = c.convictions or 0 },
        units = u,
        reports = MySQL.query.await('SELECT id, title, type, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_reports ORDER BY id DESC LIMIT 6') or {},
        warrants = MySQL.query.await('SELECT id, citizenid, name, reason, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_warrants WHERE active = 1 ORDER BY id DESC LIMIT 6') or {},
        bolos = MySQL.query.await('SELECT id, kind, title, plate, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_bolos WHERE active = 1 ORDER BY id DESC LIMIT 6') or {},
    }
end

-- المواطنين ---------------------------------------------------
function H.searchCitizens(_, d)
    local q = str(d.q, 60)
    if #q < 1 then return {} end
    local where, args = {}, {}
    for term in q:gmatch('%S+') do
        where[#where + 1] = '(citizenid LIKE ? OR charinfo LIKE ?)'
        args[#args + 1] = like(term)
        args[#args + 1] = like(term)
    end
    local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE ' .. table.concat(where, ' AND ') .. ' LIMIT 40', args) or {}
    local out, cids = {}, {}
    for _, r in ipairs(rows) do
        local ci = decode(r.charinfo)
        out[#out + 1] = { cid = r.citizenid, name = fullName(ci), dob = ci.birthdate, phone = ci.phone, gender = ci.gender }
        cids[#cids + 1] = r.citizenid
    end
    if #cids > 0 then
        local ph = string.rep('?,', #cids):sub(1, -2)
        local prof, war = {}, {}
        for _, p in ipairs(MySQL.query.await('SELECT citizenid, image, tags FROM ar_mdt_profiles WHERE citizenid IN (' .. ph .. ')', cids) or {}) do prof[p.citizenid] = p end
        for _, w in ipairs(MySQL.query.await('SELECT DISTINCT citizenid FROM ar_mdt_warrants WHERE active = 1 AND citizenid IN (' .. ph .. ')', cids) or {}) do war[w.citizenid] = true end
        for _, o in ipairs(out) do
            local p = prof[o.cid]
            o.image = p and p.image or nil
            o.tags = p and decode(p.tags) or {}
            o.wanted = war[o.cid] or false
        end
    end
    return out
end

function H.getProfile(_, d)
    local cid = str(d.cid, 50)
    local r = MySQL.single.await('SELECT citizenid, charinfo, job, metadata, money FROM players WHERE citizenid = ?', { cid })
    if not r then return nil end
    local ci, job, md = decode(r.charinfo), decode(r.job), decode(r.metadata)
    local Online = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Online then
        ci, job, md = Online.PlayerData.charinfo, Online.PlayerData.job, Online.PlayerData.metadata
    end
    local prof = MySQL.single.await('SELECT image, notes, tags FROM ar_mdt_profiles WHERE citizenid = ?', { cid }) or {}
    local vehicles = MySQL.query.await('SELECT plate, vehicle, state, garage FROM player_vehicles WHERE citizenid = ?', { cid }) or {}
    for _, v in ipairs(vehicles) do v.label = VehLabels[v.vehicle] or v.vehicle end
    local lic = md.licences or md.licenses or {}
    local licenses = {}
    for _, l in ipairs(Config.Licenses) do licenses[l.id] = lic[l.id] == true end
    return {
        cid = cid, name = fullName(ci), firstname = ci.firstname, lastname = ci.lastname,
        dob = ci.birthdate, gender = ci.gender, nationality = ci.nationality, phone = ci.phone,
        job = job.label or job.name, jobGrade = job.grade and job.grade.name or '',
        online = Online ~= nil, serverId = Online and Online.PlayerData.source or nil,
        injail = tonumber(md.injail) or 0, fingerprint = md.fingerprint, bloodtype = md.bloodtype,
        image = prof.image, notes = prof.notes or '', tags = decode(prof.tags),
        licenses = licenses, vehicles = vehicles,
        convictions = MySQL.query.await('SELECT id, charges, fine, jail, fined, jailed, note, description, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_convictions WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { cid }) or {},
        warrants = MySQL.query.await('SELECT id, reason, charges, author, active, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_warrants WHERE citizenid = ? ORDER BY active DESC, id DESC LIMIT 30', { cid }) or {},
        reports = MySQL.query.await('SELECT id, title, type, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_reports WHERE involved LIKE ? ORDER BY id DESC LIMIT 30', { like('"' .. cid .. '"') }) or {},
    }
end

function H.saveProfile(_, d)
    local cid = str(d.cid, 50)
    if cid == '' then return false end
    local image = str(d.image, 500)
    if image ~= '' and not image:match('^https?://') then image = '' end
    local tags = {}
    if type(d.tags) == 'table' then
        for _, t in ipairs(d.tags) do if #tags < 10 then tags[#tags + 1] = str(t, 30) end end
    end
    MySQL.insert.await('INSERT INTO ar_mdt_profiles (citizenid, image, notes, tags) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE image = VALUES(image), notes = VALUES(notes), tags = VALUES(tags)',
        { cid, image, str(d.notes, 4000), json.encode(tags) })
    return true
end

function H.setLicense(o, d)
    local cid, id, val = str(d.cid, 50), str(d.id, 30), d.value == true
    local valid = false
    for _, l in ipairs(Config.Licenses) do if l.id == id then valid = true end end
    if not valid then return false end
    local Online = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Online then
        local lic = Online.PlayerData.metadata.licences or {}
        lic[id] = val
        Online.Functions.SetMetaData('licences', lic)
        TriggerClientEvent('QBCore:Notify', Online.PlayerData.source, (val and 'انعطتك ' or 'انسحبت منك ') .. id, val and 'success' or 'error')
    else
        local r = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ?', { cid })
        if not r then return false end
        local md = decode(r.metadata)
        md.licences = md.licences or {}
        md.licences[id] = val
        MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(md), cid })
    end
    print(('[ar_mdt] %s %s رخصة %s لـ %s'):format(o.sign, val and 'انطى' or 'سحب', id, cid))
    return true
end

-- المركبات ----------------------------------------------------
function H.searchVehicles(_, d)
    local q = str(d.q, 20)
    if #q < 1 then return {} end
    local rows = MySQL.query.await([[SELECT v.plate, v.vehicle, v.citizenid, v.state, p.charinfo, f.stolen
        FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid
        LEFT JOIN ar_mdt_vehicles f ON f.plate = TRIM(v.plate)
        WHERE v.plate LIKE ? LIMIT 40]], { like(q) }) or {}
    for _, r in ipairs(rows) do
        r.plate = str(r.plate)
        r.label = VehLabels[r.vehicle] or r.vehicle
        r.owner = r.charinfo and fullName(r.charinfo) or 'مجهول'
        r.charinfo = nil
        r.stolen = r.stolen == 1
    end
    return rows
end

function H.getVehicle(_, d)
    local plate = str(d.plate, 20)
    local v = MySQL.single.await([[SELECT v.plate, v.vehicle, v.citizenid, v.state, v.garage, v.engine, v.body, p.charinfo
        FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid WHERE TRIM(v.plate) = ?]], { plate })
    local f = MySQL.single.await('SELECT stolen, notes FROM ar_mdt_vehicles WHERE plate = ?', { plate }) or {}
    local bolos = MySQL.query.await('SELECT id, title, description, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_bolos WHERE active = 1 AND plate = ?', { plate }) or {}
    if not v then
        return { plate = plate, unknown = true, stolen = f.stolen == 1, notes = f.notes or '', bolos = bolos }
    end
    return {
        plate = str(v.plate), model = v.vehicle, label = VehLabels[v.vehicle] or v.vehicle,
        owner = v.charinfo and fullName(v.charinfo) or 'مجهول', ownerCid = v.citizenid,
        state = v.state, garage = v.garage, engine = math.floor((v.engine or 1000) / 10), body = math.floor((v.body or 1000) / 10),
        stolen = f.stolen == 1, notes = f.notes or '', bolos = bolos,
    }
end

function H.saveVehicle(o, d)
    local plate = str(d.plate, 20)
    if plate == '' then return false end
    local stolen = d.stolen == true and 1 or 0
    local old = MySQL.single.await('SELECT stolen FROM ar_mdt_vehicles WHERE plate = ?', { plate })
    MySQL.insert.await('INSERT INTO ar_mdt_vehicles (plate, stolen, notes) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stolen = VALUES(stolen), notes = VALUES(notes)',
        { plate, stolen, str(d.notes, 2000) })
    if stolen == 1 and not (old and old.stolen == 1) then
        notifyOfficers(('🚨 تعميم: المركبة %s مسروقة'):format(plate), 'error')
    end
    return true
end

-- التقارير ----------------------------------------------------
function H.listReports(_, d)
    local q = str(d and d.q, 60)
    if q ~= '' then
        return MySQL.query.await('SELECT id, title, type, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_reports WHERE title LIKE ? OR body LIKE ? OR involved LIKE ? OR id = ? ORDER BY id DESC LIMIT 60',
            { like(q), like(q), like(q), tonumber(q) or -1 }) or {}
    end
    return MySQL.query.await('SELECT id, title, type, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_reports ORDER BY id DESC LIMIT 60') or {}
end

function H.getReport(_, d)
    local r = MySQL.single.await('SELECT id, title, type, body, involved, officers, author, author_cid, UNIX_TIMESTAMP(created_at) AS ts, UNIX_TIMESTAMP(updated_at) AS uts FROM ar_mdt_reports WHERE id = ?', { tonumber(d.id) or 0 })
    if not r then return nil end
    r.involved = decode(r.involved)
    r.officers = decode(r.officers)
    return r
end

local function cleanPeople(list, max)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, p in ipairs(list) do
        if type(p) == 'table' and #out < max then
            out[#out + 1] = { cid = str(p.cid, 50), name = str(p.name, 120), role = str(p.role, 30) }
        end
    end
    return out
end

function H.saveReport(o, d)
    local title = str(d.title, 150)
    if title == '' then return { ok = false, msg = 'اكتب عنوان التقرير' } end
    local involved = json.encode(cleanPeople(d.involved, 30))
    local officers = json.encode(cleanPeople(d.officers, 20))
    local id = tonumber(d.id)
    if id then
        MySQL.update.await('UPDATE ar_mdt_reports SET title = ?, type = ?, body = ?, involved = ?, officers = ? WHERE id = ?',
            { title, str(d.type, 60), str(d.body, 20000), involved, officers, id })
    else
        id = MySQL.insert.await('INSERT INTO ar_mdt_reports (title, type, body, involved, officers, author, author_cid) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { title, str(d.type, 60), str(d.body, 20000), involved, officers, o.sign, o.cid })
    end
    return { ok = true, id = id }
end

function H.deleteReport(o, d)
    if not o.canDelete then return false end
    MySQL.update.await('DELETE FROM ar_mdt_reports WHERE id = ?', { tonumber(d.id) or 0 })
    return true
end

-- أوامر القبض -------------------------------------------------
function H.listWarrants(_, d)
    local active = d and d.closed and 0 or 1
    return MySQL.query.await('SELECT id, citizenid, name, reason, charges, author, active, closed_by, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_warrants WHERE active = ? ORDER BY id DESC LIMIT 80', { active }) or {}
end

function H.createWarrant(o, d)
    local cid = str(d.cid, 50)
    local r = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
    if not r then return { ok = false, msg = 'المواطن مو موجود' } end
    local reason = str(d.reason, 2000)
    if reason == '' then return { ok = false, msg = 'اكتب سبب أمر القبض' } end
    local charges = {}
    if type(d.charges) == 'table' then
        for _, c in ipairs(d.charges) do if PenalById[c] then charges[#charges + 1] = PenalById[c].label end end
    end
    local name = fullName(r.charinfo)
    MySQL.insert.await('INSERT INTO ar_mdt_warrants (citizenid, name, reason, charges, author) VALUES (?, ?, ?, ?, ?)',
        { cid, name, reason, json.encode(charges), o.sign })
    notifyOfficers(('⚠️ أمر قبض جديد بحق %s'):format(name), 'error')
    return { ok = true }
end

function H.closeWarrant(o, d)
    MySQL.update.await('UPDATE ar_mdt_warrants SET active = 0, closed_by = ? WHERE id = ?', { o.sign, tonumber(d.id) or 0 })
    return true
end

function H.deleteWarrant(o, d)
    if not o.canDelete then return false end
    MySQL.update.await('DELETE FROM ar_mdt_warrants WHERE id = ?', { tonumber(d.id) or 0 })
    return true
end

-- التعميمات ---------------------------------------------------
function H.listBolos()
    return MySQL.query.await('SELECT id, kind, title, plate, description, author, UNIX_TIMESTAMP(created_at) AS ts FROM ar_mdt_bolos WHERE active = 1 ORDER BY id DESC LIMIT 80') or {}
end

function H.createBolo(o, d)
    local title = str(d.title, 150)
    if title == '' then return { ok = false, msg = 'اكتب عنوان التعميم' } end
    local kind = d.kind == 'vehicle' and 'vehicle' or 'person'
    local plate = kind == 'vehicle' and str(d.plate, 20):upper() or nil
    MySQL.insert.await('INSERT INTO ar_mdt_bolos (kind, title, plate, description, author) VALUES (?, ?, ?, ?, ?)',
        { kind, title, plate, str(d.description, 3000), o.sign })
    notifyOfficers(('📢 تعميم جديد: %s%s'):format(title, plate and (' - ' .. plate) or ''), 'primary')
    return { ok = true }
end

function H.removeBolo(o, d)
    MySQL.update.await('UPDATE ar_mdt_bolos SET active = 0 WHERE id = ?', { tonumber(d.id) or 0 })
    return true
end

-- الأحكام والغرامات --------------------------------------------
function H.sentence(o, d)
    local cid = str(d.cid, 50)
    local row = MySQL.single.await('SELECT charinfo, money FROM players WHERE citizenid = ?', { cid })
    if not row then return { ok = false, msg = 'المواطن مو موجود' } end
    -- مجموع التهم من القانون
    local fine, jail, labels = 0, 0, {}
    for _, c in ipairs(type(d.charges) == 'table' and d.charges or {}) do
        local it = PenalById[c]
        if it then
            fine, jail = fine + it.fine, jail + it.jail
            labels[#labels + 1] = it.label
        end
    end
    -- تهمة مكتوبة باليد (مو موجودة بالقانون)
    local extra = str(d.extra, 150)
    if extra ~= '' then labels[#labels + 1] = extra end
    -- الضابط يكدر يغير المدة والغرامة باليد (ضمن الحد الأعلى)
    if tonumber(d.fine) then fine = math.floor(math.max(0, math.min(tonumber(d.fine), Config.MaxFine))) end
    if tonumber(d.jail) then jail = math.floor(math.max(0, math.min(tonumber(d.jail), Config.MaxJail))) end
    local description = str(d.description, 6000)
    if #labels == 0 then return { ok = false, msg = 'اختار تهمة أو اكتب المخالفة' } end
    if fine == 0 and jail == 0 and description == '' then return { ok = false, msg = 'حط مدة سجن أو غرامة' } end
    local name = fullName(row.charinfo)
    local notes, fined, jailed = {}, 0, 0
    local Target = QBCore.Functions.GetPlayerByCitizenId(cid)

    if d.doFine and fine > 0 then
        if Target then
            Target.Functions.RemoveMoney(Config.FineAccount, fine, 'mdt-fine')
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('انسحبت منك غرامة $%d'):format(fine), 'error', 7000)
        else
            local money = decode(row.money)
            money[Config.FineAccount] = (tonumber(money[Config.FineAccount]) or 0) - fine
            MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), cid })
        end
        pcall(function() exports['qb-banking']:AddMoney(o.P.PlayerData.job.name, fine, 'MDT fine') end)
        fined = 1
    end

    if d.doJail and jail > 0 then
        if not Target then
            notes[#notes + 1] = 'ما انسجن: غير متصل'
        else
            local dist = #(GetEntityCoords(GetPlayerPed(o.src)) - GetEntityCoords(GetPlayerPed(Target.PlayerData.source)))
            if dist > Config.JailDistance then
                notes[#notes + 1] = 'ما انسجن: بعيد عن الضابط'
            else
                local date = os.date('*t')
                if date.day == 31 then date.day = 30 end
                Target.Functions.SetMetaData('injail', jail)
                Target.Functions.SetMetaData('criminalrecord', { hasRecord = true, date = date })
                TriggerClientEvent('police:client:SendToJail', Target.PlayerData.source, jail)
                jailed = 1
            end
        end
    end

    local caseId = MySQL.insert.await('INSERT INTO ar_mdt_convictions (citizenid, name, charges, fine, jail, fined, jailed, note, description, author) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, name, json.encode(labels), fine, jail, fined, jailed, table.concat(notes, ' - '), description, o.sign })

    -- إذا عليه أمر قبض ونسجن، يتسكر وحده
    if jailed == 1 then
        MySQL.update.await('UPDATE ar_mdt_warrants SET active = 0, closed_by = ? WHERE citizenid = ? AND active = 1', { o.sign, cid })
    end
    print(('[ar_mdt] %s حكم على %s: $%d / %d شهر'):format(o.sign, name, fine, jail))
    local msg = ('انسجلت القضية #%s على %s'):format(caseId or '?', name)
    if jailed == 1 then msg = msg .. (' وانسجن %d شهر'):format(jail) end
    if #notes > 0 then msg = msg .. ' (' .. table.concat(notes, '، ') .. ')' end
    return { ok = true, msg = msg, id = caseId }
end

-- القضايا (كل الأحكام اللي كتبوها كل العساكر) ------------------
local CASE_COLS = 'id, citizenid, name, charges, fine, jail, fined, jailed, note, description, author, UNIX_TIMESTAMP(created_at) AS ts'

function H.listCases(_, d)
    local q = str(d and d.q, 60)
    local rows
    if q ~= '' then
        rows = MySQL.query.await('SELECT ' .. CASE_COLS .. ' FROM ar_mdt_convictions WHERE name LIKE ? OR citizenid LIKE ? OR description LIKE ? OR charges LIKE ? OR author LIKE ? OR id = ? ORDER BY id DESC LIMIT 100',
            { like(q), like(q), like(q), like(q), like(q), tonumber(q) or -1 })
    else
        rows = MySQL.query.await('SELECT ' .. CASE_COLS .. ' FROM ar_mdt_convictions ORDER BY id DESC LIMIT 100')
    end
    rows = rows or {}
    -- القضايا القديمة اللي ما بيها اسم
    local missing = {}
    for _, r in ipairs(rows) do if not r.name then missing[#missing + 1] = r.citizenid end end
    if #missing > 0 then
        local names = {}
        for _, p in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (' .. string.rep('?,', #missing):sub(1, -2) .. ')', missing) or {}) do
            names[p.citizenid] = fullName(p.charinfo)
        end
        for _, r in ipairs(rows) do if not r.name then r.name = names[r.citizenid] or r.citizenid end end
    end
    return rows
end

-- الأشخاص القريبين من الضابط (للزنزانات)
function H.nearby(o)
    local me = GetEntityCoords(GetPlayerPed(o.src))
    local list = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local pd = v.PlayerData
        if pd.source ~= o.src then
            local dist = #(me - GetEntityCoords(GetPlayerPed(pd.source)))
            if dist <= Config.NearbyDistance then
                list[#list + 1] = { cid = pd.citizenid, name = fullName(pd.charinfo), id = pd.source, dist = math.floor(dist * 10) / 10,
                    cuffed = pd.metadata.ishandcuffed == true, injail = tonumber(pd.metadata.injail) or 0 }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- البلاغات (من ar_dispatch) ------------------------------------
function H.dispatch()
    if GetResourceState('ar_dispatch') ~= 'started' then return { off = true, list = {} } end
    return { list = exports['ar_dispatch']:GetAlerts() or {}, types = nil }
end

-- الوحدات -----------------------------------------------------
function H.units() return units() end

function H.setStatus(o, d)
    for _, s in ipairs(Config.Statuses) do
        if s.id == d.status then Status[o.cid] = s.id return true end
    end
    return false
end

function H.setCallsign(o, d)
    local cs = str(d.callsign, 10)
    if cs == '' then return false end
    o.P.Functions.SetMetaData('callsign', cs)
    return true
end

------------------------------------------------------------------
-- كل طلب إله رقم خاص، حتى الطلبات اللي تصير بنفس الوقت ما تتلاخبط
-- (callbacks مال QBCore تنحفظ بالاسم، فطلبين سوة واحد يضيع)
local function handle(src, name, data)
    local o = officer(src)
    if not o then return { err = 'ما عندك صلاحية' } end
    local fn = H[name]
    if not fn then return { err = 'أمر مو معروف: ' .. tostring(name) } end
    local t = os.clock()
    local ok, res = pcall(fn, o, type(data) == 'table' and data or {})
    if not ok then
        print('^1[ar_mdt] خطأ في ' .. name .. ': ' .. tostring(res) .. '^7')
        return { err = 'خطأ بالسيرفر (' .. name .. ')' }
    end
    if Config.Debug then print(('[ar_mdt] %s تم (%.0f ms)'):format(name, (os.clock() - t) * 1000)) end
    return { data = res == nil and false or res }
end

RegisterNetEvent('ar_mdt:req', function(id, name, data)
    local src = source
    local out = handle(src, name, data)
    -- نرسل الرد نص JSON جاهز، حتى يوصل للواجهة مثل ما هو
    local okEnc, encoded = pcall(json.encode, out)
    if not okEnc then
        print('^1[ar_mdt] رد ما ينرسل في ' .. tostring(name) .. ': ' .. tostring(encoded) .. '^7')
        encoded = json.encode({ err = 'خطأ ببيانات ' .. tostring(name) })
    end
    TriggerClientEvent('ar_mdt:res', src, id, encoded)
end)

QBCore.Functions.CreateCallback('ar_mdt:canOpen', function(src, cb)
    cb(officer(src) ~= nil)
end)

AddEventHandler('playerDropped', function()
    local P = QBCore.Functions.GetPlayer(source)
    if P then Status[P.PlayerData.citizenid] = nil end
end)
