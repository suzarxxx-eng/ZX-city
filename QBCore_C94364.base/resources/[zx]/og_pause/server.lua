local QBCore = exports['qb-core']:GetCoreObject()
local Session = {}   -- [src] = وقت الدخول
local Tickets = {}

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `og_playtime` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `minutes` INT NOT NULL DEFAULT 0,
        `rewarded` INT NOT NULL DEFAULT 0
    ) DEFAULT CHARSET=utf8mb4]])
end)

-- كل دقيقة نضيف دقيقة لعب لكل لاعب محمل
CreateThread(function()
    while true do
        Wait(60000)
        local cids = {}
        for _, P in pairs(QBCore.Functions.GetQBPlayers()) do cids[#cids + 1] = P.PlayerData.citizenid end
        if #cids > 0 then
            local vals, args = {}, {}
            for _, c in ipairs(cids) do vals[#vals + 1] = '(?, 1, 0)'; args[#args + 1] = c end
            MySQL.query('INSERT INTO og_playtime (citizenid, minutes, rewarded) VALUES ' .. table.concat(vals, ',') .. ' ON DUPLICATE KEY UPDATE minutes = minutes + 1', args)
        end
    end
end)

local function isAdmin(src)
    for _, p in ipairs(Config.AdminPerms) do
        if QBCore.Functions.HasPermission(src, p) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

local function fullName(ci)
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function playtime(cid)
    local r = MySQL.single.await('SELECT minutes, rewarded FROM og_playtime WHERE citizenid = ?', { cid }) or {}
    return tonumber(r.minutes) or 0, tonumber(r.rewarded) or 0
end

QBCore.Functions.CreateCallback('og_pause:data', function(src, cb)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    local pd = P.PlayerData
    local minutes, rewarded = playtime(pd.citizenid)
    local earned = math.floor(minutes / Config.RewardEvery)
    local players = #GetPlayers()
    local cops = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then cops = cops + 1 end
    end
    cb({
        server = Config.ServerName, tagline = Config.Tagline, discord = Config.Discord, rules = Config.Rules,
        me = {
            name = fullName(pd.charinfo), cid = pd.citizenid, id = src,
            cash = pd.money.cash or 0, bank = pd.money.bank or 0, phone = pd.charinfo.phone,
            birth = pd.charinfo.birthdate, nationality = pd.charinfo.nationality,
            job = pd.job.label, grade = pd.job.grade and pd.job.grade.name or '', onduty = pd.job.onduty,
            gang = pd.gang and pd.gang.name ~= 'none' and pd.gang.label or nil,
            session = Session[src] and (os.time() - Session[src]) or 0,
        },
        play = {
            minutes = minutes, every = Config.RewardEvery, amount = Config.RewardAmount,
            claimable = math.max(0, earned - rewarded),
            toNext = Config.RewardEvery - (minutes % Config.RewardEvery),
        },
        event = GetResourceKvpString('og_event') or '',
        players = players, maxPlayers = GetConvarInt('sv_maxclients', 48), cops = cops,
        admin = isAdmin(src),
    })
end)

QBCore.Functions.CreateCallback('og_pause:claim', function(src, cb)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb({ ok = false }) end
    local cid = P.PlayerData.citizenid
    local minutes, rewarded = playtime(cid)
    local n = math.floor(minutes / Config.RewardEvery) - rewarded
    if n <= 0 then return cb({ ok = false, msg = 'ماكو مكافأة هسه' }) end
    local amount = n * Config.RewardAmount
    MySQL.update.await('UPDATE og_playtime SET rewarded = rewarded + ? WHERE citizenid = ?', { n, cid })
    P.Functions.AddMoney(Config.RewardAccount, amount, 'og-playtime-reward')
    cb({ ok = true, msg = ('استلمت $%s مكافأة لعب'):format(amount) })
end)

QBCore.Functions.CreateCallback('og_pause:ticket', function(src, cb, data)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or type(data) ~= 'table' then return cb({ ok = false }) end
    local text = tostring(data.text or ''):sub(1, 600)
    local kind = tostring(data.kind or 'عام'):sub(1, 30)
    if #text < 5 then return cb({ ok = false, msg = 'اكتب تفاصيل أكثر' }) end
    local now = os.time()
    if Tickets[src] and now - Tickets[src] < 60 then return cb({ ok = false, msg = 'انطر دقيقة قبل تذكرة ثانية' }) end
    Tickets[src] = now
    local name = fullName(P.PlayerData.charinfo)
    local msg = ('🎫 تذكرة [%s] من %s (ID %d): %s'):format(kind, name, src, text)
    local sent = 0
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if isAdmin(id) then
            TriggerClientEvent('QBCore:Notify', id, msg, 'primary', 12000)
            TriggerClientEvent('chat:addMessage', id, { color = { 242, 193, 78 }, args = { 'تذكرة', ('[%s] %s (ID %d): %s'):format(kind, name, src, text) } })
            sent = sent + 1
        end
    end
    print('[og_pause] ' .. msg)
    cb({ ok = true, msg = sent > 0 and ('انرسلت تذكرتك لـ %d من الإدارة'):format(sent) or 'انرسلت تذكرتك، الإدارة تشوفها أول ما تتصل' })
end)

-- فعالية جاية: /setevent سباق الجمعة 9 بالليل
QBCore.Commands.Add('setevent', 'تحديد الفعالية الجاية بقائمة ESC (أدمن)', { { name = 'text', help = 'وصف الفعالية' } }, false, function(source, args)
    local text = table.concat(args, ' ')
    SetResourceKvp('og_event', text)
    TriggerClientEvent('QBCore:Notify', source, text ~= '' and 'انحفظت الفعالية' or 'انشالت الفعالية', 'success')
end, 'admin')

AddEventHandler('QBCore:Server:PlayerLoaded', function(P)
    Session[P.PlayerData.source] = os.time()
end)
AddEventHandler('playerDropped', function() Session[source] = nil Tickets[source] = nil end)

RegisterNetEvent('og_pause:server:quit', function()
    DropPlayer(source, 'طلعت من ' .. Config.ServerName .. ' — نشوفك قريب 👋')
end)
