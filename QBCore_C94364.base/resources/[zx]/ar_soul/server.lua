local QBCore = exports['qb-core']:GetCoreObject()

local Armed = {} -- [serverId] = وقت انتهاء التجهيز

local function notify(src, msg, kind)
    if src == 0 then print(msg) return end
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary')
end

local function charName(src)
    local p = QBCore.Functions.GetPlayer(src)
    if p and p.PlayerData.charinfo then
        return ('%s %s'):format(p.PlayerData.charinfo.firstname or '', p.PlayerData.charinfo.lastname or '')
    end
    return GetPlayerName(src) or ('#' .. src)
end

local function isDead(src)
    local p = QBCore.Functions.GetPlayer(src)
    local md = p and p.PlayerData.metadata or {}
    return md.isdead or md.inlaststand or GetEntityHealth(GetPlayerPed(src)) <= 0
end

local function playSoul(src)
    Armed[src] = nil
    TriggerClientEvent('ar_soul:client:disarm', src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    TriggerClientEvent('ar_soul:client:play', -1, src, coords)
    if Config.Announce then
        TriggerClientEvent('chat:addMessage', -1, {
            color = { 170, 210, 255 },
            args = { 'السماء', ('صعدت روح %s'):format(charName(src)) },
        })
    end
end

-- /soul [id] : يجهز اللاعب، وأول ما يموت تطلع روحه (إذا هو ميت هسه تطلع فوراً)
QBCore.Commands.Add('soul', 'إخراج روح لاعب عند إعدامه', { { name = 'id', help = 'رقم اللاعب' } }, true, function(source, args)
    local target = tonumber(args[1])
    if not target or not QBCore.Functions.GetPlayer(target) then
        return notify(source, 'اللاعب غير موجود', 'error')
    end
    if isDead(target) then
        playSoul(target)
        return notify(source, ('تم إخراج روح %s'):format(charName(target)), 'success')
    end
    Armed[target] = os.time() + Config.ArmTimeout * 60
    TriggerClientEvent('ar_soul:client:arm', target)
    notify(source, ('تم التجهيز: أول ما يموت %s تطلع روحه'):format(charName(target)), 'success')
end, Config.Permission)

-- /soulcancel [id] : إلغاء التجهيز
QBCore.Commands.Add('soulcancel', 'إلغاء تجهيز خروج الروح', { { name = 'id', help = 'رقم اللاعب' } }, true, function(source, args)
    local target = tonumber(args[1])
    if not target or not Armed[target] then
        return notify(source, 'هذا اللاعب مو مجهز', 'error')
    end
    Armed[target] = nil
    TriggerClientEvent('ar_soul:client:disarm', target)
    notify(source, 'تم إلغاء التجهيز', 'success')
end, Config.Permission)

-- اللاعب المجهز مات: نتأكد إنه فعلاً مجهز وميت قبل التشغيل
RegisterNetEvent('ar_soul:server:died', function()
    local src = source
    local expires = Armed[src]
    if not expires then return end
    if os.time() > expires then
        Armed[src] = nil
        return
    end
    if not isDead(src) then return end
    playSoul(src)
end)

AddEventHandler('playerDropped', function()
    Armed[source] = nil
end)
