-- ============================================================
--  تيد ام (Team Deathmatch) — غرف خاصة، تصويت على السلاح، فريقين
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()
local Rooms, nextRoom = {}, 0
local Member = {}   -- [src] = roomId

local T = Config.Tdm
local EndMatch -- تنعرف تحت

local function nameOf(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return GetPlayerName(src) or ('#' .. src) end
    return P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
end

local function count(r) local n = 0 for _ in pairs(r.players) do n = n + 1 end return n end
local function teamCount(r, t) local n = 0 for _, v in pairs(r.players) do if v == t then n = n + 1 end end return n end

-- شكل الغرفة اللي يوصل للواجهة
local function view(r)
    local players, votes = {}, {}
    for w in pairs(T.Weapons) do votes[w] = 0 end
    for s, team in pairs(r.players) do
        local st = r.stats[s] or { k = 0, d = 0 }
        players[#players + 1] = { id = s, name = nameOf(s), team = team, host = s == r.host, vote = r.votes[s], k = st.k, d = st.d }
        if r.votes[s] then votes[r.votes[s]] = (votes[r.votes[s]] or 0) + 1 end
    end
    table.sort(players, function(a, b) if a.host ~= b.host then return a.host end return a.id < b.id end)
    return {
        id = r.id, name = r.name, locked = r.code ~= nil, host = r.host, state = r.state,
        target = r.target, time = r.time, players = players, votes = votes, max = T.MaxPlayers,
        score = r.score, weapon = r.weapon, ends = r.ends and (r.ends - os.time()) or nil,
    }
end

local function push(r)
    local v = view(r)
    for s in pairs(r.players) do TriggerClientEvent('og_tdm:room', s, v) end
end

local function toRoom(r, ev, ...) for s in pairs(r.players) do TriggerClientEvent(ev, s, ...) end end

exports('TdmIn', function(src) return Member[tonumber(src)] ~= nil end)
function TdmIn(src) return Member[tonumber(src)] ~= nil end -- للأرينا بنفس السكربت

QBCore.Functions.CreateCallback('og_tdm:list', function(src, cb)
    local list = {}
    for _, r in pairs(Rooms) do
        list[#list + 1] = { id = r.id, name = r.name, host = nameOf(r.host), n = count(r), max = T.MaxPlayers, locked = r.code ~= nil, state = r.state }
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    local mine = Member[src] and Rooms[Member[src]]
    cb(json.encode({ rooms = list, mine = mine and view(mine) or false, weapons = T.Weapons, targets = T.Targets, times = T.Times }))
end)

local function canJoin(src)
    if Member[src] then return false, 'أنت أصلاً بغرفة' end
    if GetResourceState('og_arena') == 'started' and exports['og_arena']:IsIn(src) then return false, 'اطلع من الأرينا أول' end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local md = P.PlayerData.metadata
    if md.isdead or md.inlaststand then return false, 'ما تكدر وأنت مصاب' end
    if md.ishandcuffed then return false, 'ما تكدر وأنت مكلبش' end
    if (tonumber(md.injail) or 0) > 0 then return false, 'ما تكدر وأنت بالسجن' end
    return true
end

local function notify(src, msg, t) TriggerClientEvent('QBCore:Notify', src, msg, t or 'error') end

local function pickTeam(r)
    return teamCount(r, 'red') <= teamCount(r, 'blue') and 'red' or 'blue'
end

RegisterNetEvent('og_tdm:create', function(d)
    local src = source
    local ok, why = canJoin(src)
    if not ok then return notify(src, why) end
    d = type(d) == 'table' and d or {}
    nextRoom = nextRoom + 1
    local name = tostring(d.name or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24)
    if name == '' then name = 'غرفة ' .. nameOf(src) end
    local code = tostring(d.code or ''):gsub('%D', ''):sub(1, 6)
    local target = tonumber(d.target) or T.Targets[2]
    local time = tonumber(d.time) or T.Times[2]
    local function inList(v, l) for _, x in ipairs(l) do if x == v then return true end end end
    if not inList(target, T.Targets) then target = T.Targets[2] end
    if not inList(time, T.Times) then time = T.Times[2] end
    local r = {
        id = nextRoom, name = name, code = code ~= '' and code or nil, host = src, state = 'lobby',
        target = target, time = time, players = { [src] = 'red' }, votes = {}, stats = {},
        score = { red = 0, blue = 0 }, bucket = T.BucketBase + nextRoom, saved = {},
    }
    SetRoutingBucketPopulationEnabled(r.bucket, false)
    Rooms[r.id] = r
    Member[src] = r.id
    push(r)
end)

RegisterNetEvent('og_tdm:join', function(id, code)
    local src = source
    local r = Rooms[tonumber(id)]
    if not r then return notify(src, 'الغرفة مو موجودة') end
    local ok, why = canJoin(src)
    if not ok then return notify(src, why) end
    if r.state ~= 'lobby' then return notify(src, 'الجولة شغالة، انطر تخلص') end
    if count(r) >= T.MaxPlayers then return notify(src, 'الغرفة مليانة') end
    if r.code and tostring(code or '') ~= r.code then return notify(src, 'الكود غلط') end
    r.players[src] = pickTeam(r)
    Member[src] = r.id
    toRoom(r, 'og_tdm:feed', { type = 'join', name = nameOf(src) })
    push(r)
end)

local function restore(src, r)
    local pos = r.saved[src]
    SetPlayerRoutingBucket(src, 0)
    Player(src).state:set('arena', nil, true)
    if pos then TriggerClientEvent('og_tdm:finish', src, pos) end
    r.saved[src] = nil
end

local function closeRoom(r)
    for s in pairs(r.players) do Member[s] = nil TriggerClientEvent('og_tdm:room', s, false) end
    Rooms[r.id] = nil
end

local function leave(src, dropped)
    local id = Member[src]
    local r = id and Rooms[id]
    if not r then return end
    if r.state == 'playing' then
        if dropped then
            local P = QBCore.Functions.GetPlayer(src)
            local pos = r.saved[src]
            if P and pos then P.PlayerData.position = vector3(pos.x, pos.y, pos.z) pcall(function() P.Functions.Save() end) end
        else
            restore(src, r)
        end
    end
    r.players[src], r.votes[src], r.stats[src], r.saved[src] = nil, nil, nil, nil
    Member[src] = nil
    if not dropped then TriggerClientEvent('og_tdm:room', src, false) end
    if count(r) == 0 then Rooms[r.id] = nil return end
    if r.host == src then
        for s in pairs(r.players) do r.host = s break end
        toRoom(r, 'og_tdm:feed', { type = 'host', name = nameOf(r.host) })
    end
    toRoom(r, 'og_tdm:feed', { type = 'leave', name = dropped and (GetPlayerName(src) or '') or nameOf(src) })
    -- إذا فريق صار فاضي وهي شغالة، تخلص
    if r.state == 'playing' and (teamCount(r, 'red') == 0 or teamCount(r, 'blue') == 0) then
        EndMatch(r, teamCount(r, 'red') == 0 and 'blue' or 'red')
    else
        push(r)
    end
end

RegisterNetEvent('og_tdm:leave', function() leave(source) end)
AddEventHandler('playerDropped', function() leave(source, true) end)

RegisterNetEvent('og_tdm:team', function(team)
    local src = source
    local r = Rooms[Member[src] or 0]
    if not r or r.state ~= 'lobby' or (team ~= 'red' and team ~= 'blue') then return end
    if teamCount(r, team) >= T.MaxPlayers / 2 then return notify(src, 'الفريق مليان') end
    r.players[src] = team
    push(r)
end)

RegisterNetEvent('og_tdm:vote', function(w)
    local src = source
    local r = Rooms[Member[src] or 0]
    if not r or r.state ~= 'lobby' or not T.Weapons[w] then return end
    r.votes[src] = w
    push(r)
end)

-- المضيف يرتب الفرق بالتساوي
RegisterNetEvent('og_tdm:balance', function()
    local src = source
    local r = Rooms[Member[src] or 0]
    if not r or r.host ~= src or r.state ~= 'lobby' then return end
    local list = {}
    for s in pairs(r.players) do list[#list + 1] = s end
    for i = #list, 2, -1 do local j = math.random(i) list[i], list[j] = list[j], list[i] end
    for i, s in ipairs(list) do r.players[s] = (i % 2 == 1) and 'red' or 'blue' end
    push(r)
end)

local function winnerWeapon(r)
    local c = {}
    for _, w in pairs(r.votes) do c[w] = (c[w] or 0) + 1 end
    local best, top = {}, 0
    for w in pairs(T.Weapons) do
        local n = c[w] or 0
        if n > top then best, top = { w }, n elseif n == top then best[#best + 1] = w end
    end
    return best[math.random(#best)]
end

RegisterNetEvent('og_tdm:start', function()
    local src = source
    local r = Rooms[Member[src] or 0]
    if not r or r.host ~= src or r.state ~= 'lobby' then return end
    if teamCount(r, 'red') == 0 or teamCount(r, 'blue') == 0 then return notify(src, 'لازم كل فريق بي لاعب واحد على الأقل') end
    r.weapon = winnerWeapon(r)
    r.state = 'playing'
    r.score = { red = 0, blue = 0 }
    r.stats = {}
    r.ends = os.time() + r.time * 60
    local roster = {}
    for s, t in pairs(r.players) do roster[tostring(s)] = t end
    for s, t in pairs(r.players) do
        local ped = GetPlayerPed(s)
        local c = GetEntityCoords(ped)
        r.saved[s] = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
        r.stats[s] = { k = 0, d = 0 }
        SetPlayerRoutingBucket(s, r.bucket)
        Player(s).state:set('arena', 'tdm', true)
        TriggerClientEvent('og_tdm:start', s, { weapon = r.weapon, team = t, roster = roster, target = r.target, seconds = r.time * 60 })
    end
    push(r)
end)

EndMatch = function(r, winner)
    if r.state ~= 'playing' then return end
    r.state = 'ended'
    if not winner then
        winner = r.score.red > r.score.blue and 'red' or r.score.blue > r.score.red and 'blue' or 'draw'
    end
    local mvp, best = nil, -999
    for s, st in pairs(r.stats) do
        local v = st.k * 2 - st.d
        if r.players[s] and v > best then best, mvp = v, s end
    end
    toRoom(r, 'og_tdm:ended', { winner = winner, score = r.score, mvp = mvp and nameOf(mvp) or nil, view = view(r) })
    SetTimeout(T.EndScreen * 1000, function()
        if not Rooms[r.id] then return end
        for s in pairs(r.players) do restore(s, r) end
        r.state = 'lobby'
        r.ends = nil
        r.votes = {}
        push(r)
    end)
end

RegisterNetEvent('og_tdm:died', function(killer)
    local src = source
    local r = Rooms[Member[src] or 0]
    if not r or r.state ~= 'playing' then return end
    r.stats[src] = r.stats[src] or { k = 0, d = 0 }
    r.stats[src].d = r.stats[src].d + 1
    killer = tonumber(killer)
    local kt, vt = killer and r.players[killer], r.players[src]
    if kt and killer ~= src and kt ~= vt then
        r.stats[killer] = r.stats[killer] or { k = 0, d = 0 }
        r.stats[killer].k = r.stats[killer].k + 1
        r.score[kt] = r.score[kt] + 1
        toRoom(r, 'og_tdm:feed', { type = 'kill', killer = nameOf(killer), victim = nameOf(src), kt = kt, vt = vt, kid = killer, vid = src })
    else
        toRoom(r, 'og_tdm:feed', { type = 'self', victim = nameOf(src), vt = vt, vid = src })
    end
    toRoom(r, 'og_tdm:score', r.score)
    if r.score.red >= r.target then EndMatch(r, 'red')
    elseif r.score.blue >= r.target then EndMatch(r, 'blue')
    else push(r) end
end)

-- انتهاء الوقت
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for _, r in pairs(Rooms) do
            if r.state == 'playing' and r.ends and now >= r.ends then EndMatch(r) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(Rooms) do
        if r.state == 'playing' or r.state == 'ended' then for s in pairs(r.players) do restore(s, r) end end
    end
end)
