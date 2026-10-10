local QBCore = exports['qb-core']:GetCoreObject()
local In = {}      -- [src] = { mode, pos = vec4, kills, deaths }

for _, a in pairs(Config.Arenas) do
    SetRoutingBucketPopulationEnabled(a.bucket, false)  -- بدون ناس وسيارات
    SetRoutingBucketEntityLockdownMode(a.bucket, 'inactive')
end

local function nameOf(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return GetPlayerName(src) or ('#' .. src) end
    return P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
end

local function counts()
    local c = {}
    for k in pairs(Config.Arenas) do c[k] = 0 end
    for _, v in pairs(In) do c[v.mode] = (c[v.mode] or 0) + 1 end
    return c
end
exports('Counts', counts)
exports('IsIn', function(src) return In[tonumber(src)] ~= nil end)

-- يرسل لكل اللي بنفس الأرينا
local function toArena(mode, event, ...)
    for s, v in pairs(In) do if v.mode == mode then TriggerClientEvent(event, s, ...) end end
end

local function board(mode)
    local list = {}
    for s, v in pairs(In) do
        if v.mode == mode then list[#list + 1] = { id = s, name = nameOf(s), k = v.kills, d = v.deaths } end
    end
    table.sort(list, function(a, b) if a.k ~= b.k then return a.k > b.k end return a.d < b.d end)
    toArena(mode, 'og_arena:board', list)
end

RegisterNetEvent('og_arena:join', function(mode)
    local src = source
    local a = Config.Arenas[mode]
    local P = QBCore.Functions.GetPlayer(src)
    if not a or not P then return end
    if In[src] then return TriggerClientEvent('QBCore:Notify', src, 'أنت أصلاً بالأرينا', 'error') end
    if TdmIn and TdmIn(src) then return TriggerClientEvent('QBCore:Notify', src, 'اطلع من غرفة التيد ام أول', 'error') end
    local md = P.PlayerData.metadata
    if md.isdead or md.inlaststand then return TriggerClientEvent('QBCore:Notify', src, 'ما تكدر وأنت مصاب', 'error') end
    if md.ishandcuffed then return TriggerClientEvent('QBCore:Notify', src, 'ما تكدر وأنت مكلبش', 'error') end
    if (tonumber(md.injail) or 0) > 0 then return TriggerClientEvent('QBCore:Notify', src, 'ما تكدر وأنت بالسجن', 'error') end

    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    In[src] = { mode = mode, pos = vector4(c.x, c.y, c.z, GetEntityHeading(ped)), kills = 0, deaths = 0 }
    SetPlayerRoutingBucket(src, a.bucket)
    Player(src).state:set('arena', mode, true)
    TriggerClientEvent('og_arena:enter', src, mode)
    toArena(mode, 'og_arena:feed', { type = 'join', name = nameOf(src) })
    board(mode)
end)

local function leave(src, silent)
    local v = In[src]
    if not v then return end
    In[src] = nil
    SetPlayerRoutingBucket(src, 0)
    Player(src).state:set('arena', nil, true)
    TriggerClientEvent('og_arena:exit', src, v.pos)
    if not silent then
        toArena(v.mode, 'og_arena:feed', { type = 'leave', name = nameOf(src) })
        board(v.mode)
    end
end

RegisterNetEvent('og_arena:leave', function() leave(source) end)

RegisterNetEvent('og_arena:died', function(killer)
    local src = source
    local v = In[src]
    if not v then return end
    v.deaths = v.deaths + 1
    killer = tonumber(killer)
    local kv = killer and killer ~= src and In[killer]
    if kv and kv.mode == v.mode then
        kv.kills = kv.kills + 1
        toArena(v.mode, 'og_arena:feed', { type = 'kill', killer = nameOf(killer), victim = nameOf(src), kid = killer, vid = src })
    else
        toArena(v.mode, 'og_arena:feed', { type = 'self', victim = nameOf(src), vid = src })
    end
    board(v.mode)
end)

-- إذا طلع من السيرفر وهو بالأرينا، نرجع مكانه حتى ما يدخل المرة الجاية بمكان القتال
AddEventHandler('playerDropped', function()
    local src = source
    local v = In[src]
    if not v then return end
    In[src] = nil
    local P = QBCore.Functions.GetPlayer(src)
    if P then
        P.PlayerData.position = vector3(v.pos.x, v.pos.y, v.pos.z)
        pcall(function() P.Functions.Save() end)
    end
    toArena(v.mode, 'og_arena:feed', { type = 'leave', name = GetPlayerName(src) or '' })
    board(v.mode)
end)

QBCore.Commands.Add(Config.LeaveCommand, 'اطلع من الأرينا', {}, false, function(source) leave(source) end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for s in pairs(In) do leave(s, true) end
end)
