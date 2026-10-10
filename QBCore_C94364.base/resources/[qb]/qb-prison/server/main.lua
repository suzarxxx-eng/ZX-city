local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local sharedItems = exports['qb-core']:GetShared('Items')
local GotItems = {}
local AlarmActivated = false

RegisterNetEvent('prison:server:SetJailStatus', function(jailTime)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    Player.SetMetaData('injail', jailTime)
    if jailTime > 0 then
        if Player.PlayerData.job.name ~= 'unemployed' then
            -- remember the job and rank so they can be restored when the belongings are collected
            Player.SetMetaData('jailjob', { name = Player.PlayerData.job.name, grade = Player.PlayerData.job.grade.level })
            Player.SetJob('unemployed')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('info.lost_job'))
        end
    else
        GotItems[source] = nil
    end
end)

RegisterNetEvent('prison:server:SaveJailItems', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    if (Player.PlayerData.metadata.injail or 0) <= 0 then return end
    if not Player.PlayerData.metadata['jailitems'] or table.type(Player.PlayerData.metadata['jailitems']) == 'empty' then
        Player.SetMetaData('jailitems', Player.PlayerData.items)
        Player.AddMoney('cash', 80, 'jail money')
        Wait(2000)
        Player.ClearInventory()
    end
end)

RegisterNetEvent('prison:server:GiveJailItems', function(escaped)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    if (Player.PlayerData.metadata.injail or 0) <= 0 then return end
    if escaped then
        Player.SetMetaData('jailitems', {})
        return
    end
    for _, v in pairs(Player.PlayerData.metadata['jailitems']) do
        exports['qb-inventory']:AddItem(src, v.name, v.amount, false, v.info, 'prison:server:GiveJailItems')
    end
    Player.SetMetaData('jailitems', {})
end)

local function getLockerItems(Player)
    local items = Player.PlayerData.metadata['jailitems']
    if not items or table.type(items) == 'empty' then return nil end
    return items
end

QBCore.Functions.CreateCallback('prison:server:HasLockerItems', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)
    cb(Player ~= nil and (Player.PlayerData.metadata.injail or 0) <= 0 and getLockerItems(Player) ~= nil)
end)

RegisterNetEvent('prison:server:ClaimLockerItems', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player or (Player.PlayerData.metadata.injail or 0) > 0 then return end
    local items = getLockerItems(Player)
    local jailJob = Player.PlayerData.metadata['jailjob']
    local hasJob = jailJob and jailJob.name ~= nil
    if not items and not hasJob then
        TriggerClientEvent('QBCore:Notify', src, 'ماكو اغراض لك بالوكر', 'error')
        return
    end
    local ped = GetPlayerPed(src)
    local l = Config.Locations['locker']
    if ped and ped ~= 0 and #(GetEntityCoords(ped) - vector3(l.x, l.y, l.z)) > 5.0 then return end
    if hasJob then
        Player.SetMetaData('jailjob', {})
        Player.SetJob(jailJob.name, jailJob.grade)
        TriggerClientEvent('QBCore:Notify', src, 'رجعتلك وظيفتك ورتبتك', 'success')
    end
    if items then
        Player.SetMetaData('jailitems', {})
        for _, v in pairs(items) do
            exports['qb-inventory']:AddItem(src, v.name, v.amount, false, v.info, 'prison:server:ClaimLockerItems')
        end
    end
    TriggerClientEvent('QBCore:Notify', src, Lang:t('info.received_property'), 'success')
    TriggerClientEvent('prison:client:AfterClaim', src)
end)

RegisterNetEvent('prison:server:ResetJailItems', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    Player.SetMetaData('jailitems', {})
end)

local function arPrisonAlert()
    if GetResourceState('ar_dispatch') == 'started' then
        TriggerEvent('ar_dispatch:server:alert', { type = 'prison', coords = vector3(1693.33, 2569.51, 45.55) })
    end
end

RegisterNetEvent('prison:server:SecurityLockdown', function()
    arPrisonAlert()
    TriggerClientEvent('prison:client:SetLockDown', -1, true)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player = exports['qb-core']:GetPlayer(v)
        if Player then
            if Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty then
                TriggerClientEvent('prison:client:PrisonBreakAlert', v)
            end
        end
    end
end)

RegisterNetEvent('prison:server:SetGateHit', function(key)
    TriggerClientEvent('prison:client:SetGateHit', -1, key, true)
    if math.random(1, 100) <= 50 then
        arPrisonAlert()
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            local Player = exports['qb-core']:GetPlayer(v)
            if Player then
                if Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty then
                    TriggerClientEvent('prison:client:PrisonBreakAlert', v)
                end
            end
        end
    end
end)

RegisterNetEvent('prison:server:CheckRecordStatus', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    local CriminalRecord = Player.PlayerData.metadata['criminalrecord']
    local currentDate = os.date('*t')

    if (CriminalRecord['date'].month + 1) == 13 then
        CriminalRecord['date'].month = 0
    end

    if CriminalRecord['hasRecord'] then
        if currentDate.month == (CriminalRecord['date'].month + 1) or currentDate.day == (CriminalRecord['date'].day - 1) then
            CriminalRecord['hasRecord'] = false
            CriminalRecord['date'] = nil
        end
    end
end)

RegisterNetEvent('prison:server:JailAlarm', function()
    if AlarmActivated then return end
    local playerPed = GetPlayerPed(source)
    local coords = GetEntityCoords(playerPed)
    local middle = vec2(Config.Locations['middle'].x, Config.Locations['middle'].y)
    if #(coords.xy - middle) < 200 then return error('"prison:server:JailAlarm" triggered whilst the player was too close to the prison, cancelled event') end
    TriggerClientEvent('prison:client:JailAlarm', -1, true)
    SetTimeout(5 * 60000, function()
        TriggerClientEvent('prison:client:JailAlarm', -1, false)
    end)
end)

RegisterNetEvent('prison:server:CheckChance', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player or Player.PlayerData.metadata.injail == 0 or GotItems[src] then return end
    local chance = math.random(100)
    local odd = math.random(100)
    if chance ~= odd then return end
    if not exports['qb-inventory']:AddItem(src, 'phone', 1, false, false, 'prison:server:CheckChance') then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['phone'], 'add')
    TriggerClientEvent('QBCore:Notify', src, Lang:t('success.found_phone'), 'success')
    GotItems[src] = true
end)

QBCore.Functions.CreateCallback('prison:server:IsAlarmActive', function(_, cb)
    cb(AlarmActivated)
end)
