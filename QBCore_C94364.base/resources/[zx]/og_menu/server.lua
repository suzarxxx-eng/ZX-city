local QBCore = exports['qb-core']:GetCoreObject()

local function counts()
    local all, cops, ems = 0, 0, 0
    for _, P in pairs(QBCore.Functions.GetQBPlayers()) do
        all = all + 1
        local j = P.PlayerData.job
        if j.onduty and Config.PoliceJobs[j.name] then cops = cops + 1 end
        if j.onduty and Config.EmsJobs[j.name] then ems = ems + 1 end
    end
    return all, cops, ems
end

local function arenas(src)
    if GetResourceState('og_arena') ~= 'started' then return nil end
    local ok, c = pcall(function() return exports['og_arena']:Counts() end)
    local okIn, inA = pcall(function() return exports['og_arena']:IsIn(src) end)
    return { counts = ok and c or {}, inside = okIn and inA or false }
end

QBCore.Functions.CreateCallback('og_menu:data', function(src, cb)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    local pd = P.PlayerData
    local ci, job, md = pd.charinfo, pd.job, pd.metadata
    local all, cops, ems = counts()
    local veh = MySQL.query.await('SELECT plate, vehicle, state, garage FROM player_vehicles WHERE citizenid = ? LIMIT 12', { pd.citizenid }) or {}
    for _, v in ipairs(veh) do
        local s = QBCore.Shared.Vehicles[v.vehicle]
        v.label = s and ((s.brand or '') .. ' ' .. (s.name or v.vehicle)) or v.vehicle
    end
    local cs = md.callsign
    if cs == 'NO CALLSIGN' then cs = nil end
    cb(json.encode({
        title = Config.Title, subtitle = Config.Subtitle, discord = Config.Discord,
        name = (ci.firstname or '') .. ' ' .. (ci.lastname or ''),
        cid = pd.citizenid, id = src, phone = ci.phone, birth = ci.birthdate,
        cash = pd.money.cash or 0, bank = pd.money.bank or 0,
        job = job.label, grade = job.grade and job.grade.name or '', onduty = job.onduty == true, callsign = cs,
        online = all, cops = cops, ems = ems, maxPlayers = GetConvarInt('sv_maxclients', 48),
        vehicles = veh, arena = arenas(src),
    }))
end)

RegisterNetEvent('og_menu:quit', function()
    DropPlayer(source, 'طلعت من مدينة OG — نشوفك قريب')
end)
