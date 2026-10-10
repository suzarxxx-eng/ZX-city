local QBCore = exports['qb-core']:GetCoreObject()
local Ops = { chief = nil, deputy = nil } -- { src, cid, name, callsign }

local function notify(src, msg, typ) TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary', 6000) end

local function allowed(P)
    return P and Config.Jobs[P.PlayerData.job.name]
end

local function display(P)
    local pd = P.PlayerData
    local cs = pd.metadata.callsign
    if cs == 'NO CALLSIGN' or cs == '' then cs = nil end
    local name = ((pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name, cs
end

local function sync()
    local function pack(s) return s and { cid = s.cid, name = s.name, callsign = s.callsign, src = s.src } or false end
    GlobalState.arOps = { chief = pack(Ops.chief), deputy = pack(Ops.deputy) }
    TriggerEvent('ar_ops:changed')
end

local function announce(msg)
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local pd = v.PlayerData
        if Config.Jobs[pd.job.name] and pd.job.onduty then notify(pd.source, msg, 'primary') end
    end
end

local function roleOf(src)
    if Ops.chief and Ops.chief.src == src then return 'chief' end
    if Ops.deputy and Ops.deputy.src == src then return 'deputy' end
end

local function release(src, why)
    local r = roleOf(src)
    if not r then return end
    local s = Ops[r]
    Ops[r] = nil
    sync()
    announce(('📡 %s ترك %s%s'):format(s.name, r == 'chief' and 'مركز العمليات' or 'نيابة مركز العمليات', why and (' (' .. why .. ')') or ''))
end

exports('GetRole', function(src)
    local r = roleOf(tonumber(src))
    return r and Config.Labels[r] or nil, r
end)
exports('GetOps', function() return Ops end)

-- تسجيل دخول / خروج من المكتب
RegisterNetEvent('ar_ops:server:duty', function(on)
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    if not allowed(P) then return end
    on = on == true
    if P.PlayerData.job.onduty == on then return end
    P.Functions.SetJobDuty(on)
    TriggerEvent('QBCore:Server:SetDuty', src, on)
    TriggerClientEvent('QBCore:Client:SetDuty', src, on)
    TriggerEvent('police:server:UpdateCurrentCops')
    if on then
        notify(src, 'سجلت دخول — أنت هسه بالدوام', 'success')
    else
        release(src, 'سجل خروج')
        notify(src, 'سجلت خروج — انتهى دوامك', 'error')
    end
end)

-- استلام / ترك مركز العمليات
RegisterNetEvent('ar_ops:server:take', function(role)
    local src = source
    if role ~= 'chief' and role ~= 'deputy' then return end
    local P = QBCore.Functions.GetPlayer(src)
    if not allowed(P) then return end
    if not P.PlayerData.job.onduty then return notify(src, 'لازم تسجل دخول أول', 'error') end
    local min = role == 'chief' and Config.ChiefMinGrade or Config.DeputyMinGrade
    if (tonumber(P.PlayerData.job.grade.level) or 0) < min then return notify(src, 'رتبتك ما تسمح', 'error') end
    local cur = Ops[role]
    if cur and cur.src ~= src and QBCore.Functions.GetPlayer(cur.src) then
        return notify(src, ('%s مستلم من قبل %s'):format(Config.Labels[role], cur.name), 'error')
    end
    if roleOf(src) and roleOf(src) ~= role then release(src) end
    local name, cs = display(P)
    Ops[role] = { src = src, cid = P.PlayerData.citizenid, name = name, callsign = cs }
    sync()
    notify(src, ('استلمت %s'):format(role == 'chief' and 'مركز العمليات' or 'نيابة مركز العمليات'), 'success')
    announce(('📡 %s%s استلم %s'):format(cs and ('[' .. cs .. '] ') or '', name, role == 'chief' and 'مركز العمليات' or 'نيابة مركز العمليات'))
end)

RegisterNetEvent('ar_ops:server:leave', function()
    release(source)
end)

-- يتحرر المركز إذا طلع من الدوام / غير وظيفته / طلع من السيرفر
AddEventHandler('QBCore:Server:SetDuty', function(src, on)
    if not on then release(src, 'طلع من الدوام') end
end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if not Config.Jobs[job.name] or not job.onduty then release(src) end
end)
AddEventHandler('QBCore:Server:OnPlayerUpdated', function(src, key)
    if key ~= 'job' then return end
    local P = QBCore.Functions.GetPlayer(src)
    if P and (not allowed(P) or not P.PlayerData.job.onduty) then release(src) end
end)
AddEventHandler('playerDropped', function() release(source, 'طلع من السيرفر') end)

-- المكاتب المضافة من اللعبة
local function loadDesks()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'desks.json')
    local ok, list = pcall(json.decode, raw or '[]')
    return (ok and type(list) == 'table') and list or {}
end
local Extra = loadDesks()

RegisterNetEvent('ar_ops:server:getDesks', function()
    TriggerClientEvent('ar_ops:client:desks', source, Extra)
end)

QBCore.Commands.Add('opsdesk', 'إضافة مكتب دوام وعمليات بمكانك (أدمن)', {}, false, function(source)
    local ped = GetPlayerPed(source)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    -- المكتب يكون قدامه بنص متر
    local r = math.rad(h)
    local pos = { x = c.x - math.sin(r) * 0.8, y = c.y + math.cos(r) * 0.8, z = c.z, heading = h }
    Extra[#Extra + 1] = pos
    SaveResourceFile(GetCurrentResourceName(), 'desks.json', json.encode(Extra), -1)
    TriggerClientEvent('ar_ops:client:desks', -1, Extra)
    notify(source, ('انضاف مكتب (%d) — يبين هسه بالعين'):format(#Extra), 'success')
end, 'admin')

QBCore.Commands.Add('opsdeskremove', 'شيل آخر مكتب انضاف (أدمن)', {}, false, function(source)
    if #Extra == 0 then return notify(source, 'ماكو مكاتب مضافة', 'error') end
    table.remove(Extra)
    SaveResourceFile(GetCurrentResourceName(), 'desks.json', json.encode(Extra), -1)
    TriggerClientEvent('ar_ops:client:desks', -1, Extra)
    notify(source, 'انشال آخر مكتب', 'success')
end, 'admin')

AddEventHandler('onResourceStart', function(r) if r == GetCurrentResourceName() then sync() end end)
