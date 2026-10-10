local QBCore = exports['qb-core']:GetCoreObject()

Config = Config or {}
Config.LoginZone = Config.LoginZone or { enabled = false, coords = vector3(0, 0, 0), job = 'police', grade = 4 }
Config.Search = Config.Search or { enabled = false, allowedJobs = {}, maxDistance = 3.0 }

-- تسجيل الدخول العسكري من المنطقة: يتأكد إن اللاعب فعلاً واقف بالمكان قبل ما يعطيه الوظيفة
RegisterNetEvent('qb-target:takejob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local zone = Config.LoginZone
    if not zone.enabled then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local dist = #(GetEntityCoords(ped) - zone.coords)
    if dist > 5.0 then return end -- بعيد عن المنطقة => تجاهل (يمنع الاستغلال من أي مكان)

    Player.Functions.SetJob(zone.job, zone.grade)
    local rank = Player.PlayerData.job and Player.PlayerData.job.grade and Player.PlayerData.job.grade.name or ''
    TriggerClientEvent('QBCore:Notify', src, ('تم تسجيل دخولك كـ عسكري - %s'):format(rank), 'success')
end)

-- تفتيش شخص: لازم يكون عندك وظيفة مسموحة + قريب من الهدف
RegisterNetEvent('qb-target:searchPlayer', function(targetId)
    local src = source
    local Searcher = QBCore.Functions.GetPlayer(src)
    if not Searcher then return end

    local cfg = Config.Search
    if not cfg.enabled then return end

    local job = Searcher.PlayerData.job and Searcher.PlayerData.job.name
    local allowed = false
    for _, j in ipairs(cfg.allowedJobs) do
        if j == job then allowed = true break end
    end
    if not allowed then
        TriggerClientEvent('QBCore:Notify', src, 'ما عندك صلاحية للتفتيش', 'error')
        return
    end

    targetId = tonumber(targetId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target then return end

    local sPed, tPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if sPed == 0 or tPed == 0 then return end
    if #(GetEntityCoords(sPed) - GetEntityCoords(tPed)) > cfg.maxDistance then return end

    local cash = Target.PlayerData.money and Target.PlayerData.money.cash or 0
    local bank = Target.PlayerData.money and Target.PlayerData.money.bank or 0
    TriggerClientEvent('qb-target:searchResult', src, {
        cash = cash,
        bank = bank,
    })
    TriggerClientEvent('QBCore:Notify', targetId, 'يتم تفتيشك الآن', 'primary')
    -- فتح حقيبة اللاعب للمفتّش
    if GetResourceState('qb-inventory') == 'started' then
        exports['qb-inventory']:OpenInventoryById(src, targetId)
    end
end)

-- أمر إداري فقط لتعيين نفسك بوليس (كان سابقاً مفتوح للجميع = ثغرة)
QBCore.Commands.Add('setpolice', 'تعيين نفسك بوليس (للمشرفين فقط)', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    Player.Functions.SetJob(Config.LoginZone.job, Config.LoginZone.grade)
    TriggerClientEvent('QBCore:Notify', source, 'تم تعيينك بوليس بنجاح', 'success')
end, 'admin')
