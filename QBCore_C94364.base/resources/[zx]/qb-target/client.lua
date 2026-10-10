local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData() or {}

-- مخازن الخيارات (متوافقة مع qb-target الأصلي)
local Zones, Entities, Models, Bones = {}, {}, {}, {}
local Types = {}          -- ped / vehicle / object / player
local Peds = {}

local targetActive, menuFocus, allowTarget = false, false, true
local current = {}        -- الخيارات الظاهرة حالياً { opt, entity }

---------------------------------------------------------------- بيانات اللاعب
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() PlayerData = QBCore.Functions.GetPlayerData() end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() PlayerData = {} end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val) PlayerData = val end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) PlayerData.job = job end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang) PlayerData.gang = gang end)
-- التحديثات الجزئية (metadata لما تموت أو تنعش، الوظيفة...) ما تجي بحدث SetPlayerData
RegisterNetEvent('QBCore:Client:OnPlayerUpdated', function(key, val)
    if key == 'all' then PlayerData = val or {} return end
    if key then PlayerData[key] = val end
end)

local function refreshPlayerData()
    local ok, pd = pcall(QBCore.Functions.GetPlayerData)
    if ok and type(pd) == 'table' then PlayerData = pd end
end

---------------------------------------------------------------- أدوات التخزين
local function toList(v) return type(v) == 'table' and v or { v } end
local function modelKey(m) return type(m) == 'string' and joaat(m) or m end

local function normalize(params)
    local list = {}
    if type(params) ~= 'table' then return list end
    local dist = params.distance or Config.DefaultDistance
    for _, o in pairs(params.options or {}) do
        if type(o) == 'table' and o.label then
            o.distance = o.distance or dist
            list[#list + 1] = o
        end
    end
    return list
end

local function addTo(store, key, params)
    if key == nil then return end
    local existing = store[key] or {}
    for _, o in ipairs(normalize(params)) do
        local replaced = false
        for i, e in ipairs(existing) do
            if e.label == o.label then existing[i], replaced = o, true break end
        end
        if not replaced then existing[#existing + 1] = o end
    end
    store[key] = existing
end

local function removeFrom(store, key, labels)
    if key == nil or not store[key] then return end
    if labels == nil then store[key] = nil return end
    local drop = {}
    for _, l in pairs(toList(labels)) do drop[l] = true end
    local keep = {}
    for _, o in ipairs(store[key]) do
        if not drop[o.label] then keep[#keep + 1] = o end
    end
    store[key] = #keep > 0 and keep or nil
end

---------------------------------------------------------------- الشروط (وظيفة / عصابة / غرض / ...)
local function matchGroup(req, group)
    if req == nil then return true end
    if not group or not group.name then return false end
    if type(req) == 'string' then return req == 'all' or req == group.name end
    if type(req) == 'table' then
        if req.all ~= nil then return true end
        local g = req[group.name]
        if g ~= nil then
            local level = group.grade and (group.grade.level or group.grade) or 0
            return (tonumber(level) or 0) >= (tonumber(g) or 0)
        end
        for _, n in pairs(req) do
            if n == group.name or n == 'all' then return true end
        end
        return false
    end
    return true
end

local function matchCid(req)
    if req == nil then return true end
    local cid = PlayerData.citizenid
    if type(req) == 'string' then return req == cid end
    if type(req) == 'table' then
        if req[cid] then return true end
        for _, v in pairs(req) do if v == cid then return true end end
        return false
    end
    return true
end

local function hasItem(req)
    if req == nil then return true end
    local ok, res = pcall(function() return exports['qb-inventory']:HasItem(req) end)
    return ok and res
end

local function canShow(o, entity, dist)
    if dist > (o.distance or Config.DefaultDistance) then return false end
    if not matchGroup(o.job, PlayerData.job) then return false end
    if not matchGroup(o.gang, PlayerData.gang) then return false end
    if not matchCid(o.citizenid) then return false end
    if not hasItem(o.item) then return false end
    if o.canInteract then
        local ok, res = pcall(o.canInteract, entity, dist, o)
        if not ok or not res then return false end
    end
    return true
end

---------------------------------------------------------------- التصويب
local function rotToDir(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

function RaycastCamera(flag, distance)
    local cam = GetGameplayCamCoord()
    local dest = cam + rotToDir(GetGameplayCamRot(2)) * (distance or Config.MaxDistance)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, flag or -1, PlayerPedId(), 4)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)
    if hit ~= 1 and hit ~= true then return false, vector3(0, 0, 0), 0, 0 end
    local etype = (entity ~= 0 and DoesEntityExist(entity)) and GetEntityType(entity) or 0
    if etype == 0 then entity = 0 end
    return true, endCoords, entity, etype
end

local function collect(out, list, entity, dist)
    if not list then return end
    for _, o in ipairs(list) do
        if canShow(o, entity, dist) then out[#out + 1] = { opt = o, entity = entity } end
    end
end

local function gather()
    local out = {}
    local hit, coords, entity, etype = RaycastCamera(-1)
    if not hit then return out end
    local pcoords = GetEntityCoords(PlayerPedId())
    local dist = #(pcoords - coords)

    if entity ~= 0 then
        collect(out, Entities[entity], entity, dist)
        collect(out, Models[GetEntityModel(entity)], entity, dist)

        if etype == 1 then
            collect(out, Types[IsPedAPlayer(entity) and 'player' or 'ped'], entity, dist)
        elseif etype == 2 then
            collect(out, Types.vehicle, entity, dist)
            local best, bestD, bestPos
            for bone in pairs(Bones) do
                local idx = GetEntityBoneIndexByName(entity, bone)
                if idx ~= -1 then
                    local pos = GetWorldPositionOfEntityBone(entity, idx)
                    local d = #(coords - pos)
                    if d <= 1.6 and (not bestD or d < bestD) then best, bestD, bestPos = bone, d, pos end
                end
            end
            if best then collect(out, Bones[best], entity, #(pcoords - bestPos)) end
        elseif etype == 3 then
            collect(out, Types.object, entity, dist)
        end
    end

    for _, z in pairs(Zones) do
        if z.entity then
            if entity ~= 0 and z.entity == entity then collect(out, z.options, entity, dist) end
        elseif z.zone and z.zone:isPointInside(coords) then
            collect(out, z.options, entity, dist)
        end
    end

    table.sort(out, function(a, b) return (a.opt.num or 99) < (b.opt.num or 99) end)
    return out
end

local function signature(list)
    local s = {}
    for i, v in ipairs(list) do s[i] = v.opt.label .. '@' .. tostring(v.entity) end
    return table.concat(s, '|')
end

local function serialize(list)
    local t = {}
    for i, v in ipairs(list) do
        t[i] = { label = tostring(v.opt.label), icon = type(v.opt.icon) == 'string' and v.opt.icon or nil }
    end
    return t
end

---------------------------------------------------------------- فتح / إغلاق
local function disableTarget()
    if not targetActive then return end
    targetActive, menuFocus = false, false
    current = {}
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function canTarget()
    if targetActive then return false, 'already open' end
    if not allowTarget then return false, 'disabled by AllowTargeting(false)' end
    if IsPauseMenuActive() then return false, 'pause menu' end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return false, 'player dead' end
    local md = PlayerData.metadata
    if md and (md.isdead or md.inlaststand or md.ishandcuffed) then return false, 'dead / laststand / handcuffed' end
    if not Config.EnableInVehicle and IsPedInAnyVehicle(ped, false) then return false, 'in vehicle' end
    return true
end

local function enableTarget()
    refreshPlayerData()
    local ok = canTarget()
    if not ok then return end
    targetActive = true
    SendNUIMessage({ action = 'open' })

    CreateThread(function()
        local lastSig = nil
        while targetActive do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)  -- ضرب
            DisableControlAction(0, 25, true)  -- تصويب
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)

            if not menuFocus then
                current = gather()
                local sig = signature(current)
                if sig ~= lastSig then
                    lastSig = sig
                    SendNUIMessage({ action = 'options', options = serialize(current) })
                end
                -- كليك يسار = اختيار بالماوس
                if #current > 0 and IsDisabledControlJustReleased(0, 24) then
                    menuFocus = true
                    SetNuiFocus(true, true)
                    SetNuiFocusKeepInput(false)
                    SetCursorLocation(0.5, 0.5)
                    SendNUIMessage({ action = 'focus' })
                end
            end
            Wait(0)
        end
    end)
end

local function runOption(o, entity)
    if not o then return end
    CreateThread(function()
        if o.action then
            o.action(entity)
            return
        end
        if not o.event then return end
        local data = {}
        for k, v in pairs(o) do
            if type(v) ~= 'function' then data[k] = v end
        end
        data.entity = entity
        if o.type == 'server' then
            TriggerServerEvent(o.event, data)
        elseif o.type == 'command' then
            ExecuteCommand(o.event)
        elseif o.type == 'qbcommand' then
            TriggerServerEvent('QBCore:CallCommand', o.event, data)
        else
            TriggerEvent(o.event, data)
        end
    end)
end

RegisterCommand('+playerTarget', enableTarget, false)
RegisterCommand('-playerTarget', function()
    if not menuFocus then disableTarget() end
end, false)
RegisterKeyMapping('+playerTarget', 'العين (التفاعل)', 'keyboard', Config.OpenKey or 'LMENU')
TriggerEvent('chat:removeSuggestion', '/+playerTarget')
TriggerEvent('chat:removeSuggestion', '/-playerTarget')

RegisterNUICallback('select', function(data, cb)
    cb('ok')
    local pick = current[tonumber(data.index) or 0]
    disableTarget()
    if pick then runOption(pick.opt, pick.entity) end
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    disableTarget()
end)

---------------------------------------------------------------- Exports (نفس أسماء qb-target)
local function addZone(name, data)
    if Zones[name] and Zones[name].zone then pcall(function() Zones[name].zone:destroy() end) end
    Zones[name] = data
    return data.zone
end

local function zoneOpts(name, options)
    options = options or {}
    options.name = options.name or name
    if options.debugPoly == nil then options.debugPoly = Config.Debug end
    return options
end

function AddCircleZone(name, center, radius, options, targetoptions)
    local zone = CircleZone:Create(vector3(center.x, center.y, center.z), radius, zoneOpts(name, options))
    return addZone(name, { zone = zone, options = normalize(targetoptions) })
end

function AddBoxZone(name, center, length, width, options, targetoptions)
    local zone = BoxZone:Create(vector3(center.x, center.y, center.z), length, width, zoneOpts(name, options))
    return addZone(name, { zone = zone, options = normalize(targetoptions) })
end

function AddPolyZone(name, points, options, targetoptions)
    local zone = PolyZone:Create(points, zoneOpts(name, options))
    return addZone(name, { zone = zone, options = normalize(targetoptions) })
end

function AddComboZone(zones, options, targetoptions)
    options = zoneOpts(options and options.name or ('combo_' .. GetGameTimer()), options)
    local zone = ComboZone:Create(zones, options)
    return addZone(options.name, { zone = zone, options = normalize(targetoptions) })
end

function AddEntityZone(name, entity, options, targetoptions)
    return addZone(name, { entity = entity, options = normalize(targetoptions) })
end

function RemoveZone(name)
    if not Zones[name] then return end
    if Zones[name].zone then pcall(function() Zones[name].zone:destroy() end) end
    Zones[name] = nil
end

function AddTargetEntity(entities, params) for _, e in pairs(toList(entities)) do addTo(Entities, e, params) end end
function RemoveTargetEntity(entities, labels) for _, e in pairs(toList(entities)) do removeFrom(Entities, e, labels) end end
function AddTargetModel(models, params) for _, m in pairs(toList(models)) do addTo(Models, modelKey(m), params) end end
function RemoveTargetModel(models, labels) for _, m in pairs(toList(models)) do removeFrom(Models, modelKey(m), labels) end end
function AddTargetBone(bones, params) for _, b in pairs(toList(bones)) do addTo(Bones, b, params) end end
function RemoveTargetBone(bones, labels) for _, b in pairs(toList(bones)) do removeFrom(Bones, b, labels) end end

local typeNames = { [1] = 'ped', [2] = 'vehicle', [3] = 'object', [4] = 'player' }
function AddGlobalType(t, params) addTo(Types, typeNames[t] or t, params) end
function RemoveGlobalType(t, labels) removeFrom(Types, typeNames[t] or t, labels) end
function AddGlobalPed(params) addTo(Types, 'ped', params) end
function AddGlobalVehicle(params) addTo(Types, 'vehicle', params) end
function AddGlobalObject(params) addTo(Types, 'object', params) end
function AddGlobalPlayer(params) addTo(Types, 'player', params) end
function RemoveGlobalPed(labels) removeFrom(Types, 'ped', labels) end
function RemoveGlobalVehicle(labels) removeFrom(Types, 'vehicle', labels) end
function RemoveGlobalObject(labels) removeFrom(Types, 'object', labels) end
function RemoveGlobalPlayer(labels) removeFrom(Types, 'player', labels) end

local function spawnOne(d)
    local model = modelKey(d.model)
    if not model or not IsModelValid(model) then return end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then return end
    local c = d.coords
    local ped = CreatePed(0, model, c.x, c.y, d.minusOne and c.z - 1.0 or c.z, c.w or 0.0, d.networked or false, true)
    SetModelAsNoLongerNeeded(model)
    if d.freeze then FreezeEntityPosition(ped, true) end
    if d.invincible then SetEntityInvincible(ped, true) end
    if d.blockevents then SetBlockingOfNonTemporaryEvents(ped, true) end
    if d.animDict and d.anim then
        RequestAnimDict(d.animDict)
        local t = GetGameTimer() + 3000
        while not HasAnimDictLoaded(d.animDict) and GetGameTimer() < t do Wait(10) end
        TaskPlayAnim(ped, d.animDict, d.anim, 8.0, 0.0, -1, d.flag or 1, 0.0, false, false, false)
    end
    if d.scenario then TaskStartScenarioInPlace(ped, d.scenario, 0, true) end
    if d.target then
        if d.target.useModel then AddTargetModel(model, d.target) else AddTargetEntity(ped, d.target) end
    end
    d.currentpednumber = ped
    Peds[#Peds + 1] = ped
end

function SpawnPed(data)
    CreateThread(function()
        if data.model then spawnOne(data) else for _, d in pairs(data) do spawnOne(d) end end
    end)
end

function DeletePeds()
    for _, p in ipairs(Peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    Peds = {}
end

function AllowTargeting(state)
    allowTarget = state and true or false
    if not allowTarget then disableTarget() end
end

exports('AddCircleZone', AddCircleZone)
exports('AddBoxZone', AddBoxZone)
exports('AddPolyZone', AddPolyZone)
exports('AddComboZone', AddComboZone)
exports('AddEntityZone', AddEntityZone)
exports('RemoveZone', RemoveZone)
exports('AddTargetEntity', AddTargetEntity)
exports('RemoveTargetEntity', RemoveTargetEntity)
exports('AddTargetModel', AddTargetModel)
exports('RemoveTargetModel', RemoveTargetModel)
exports('AddTargetBone', AddTargetBone)
exports('RemoveTargetBone', RemoveTargetBone)
exports('AddGlobalType', AddGlobalType)
exports('RemoveGlobalType', RemoveGlobalType)
exports('AddGlobalPed', AddGlobalPed)
exports('AddGlobalVehicle', AddGlobalVehicle)
exports('AddGlobalObject', AddGlobalObject)
exports('AddGlobalPlayer', AddGlobalPlayer)
exports('RemoveGlobalPed', RemoveGlobalPed)
exports('RemoveGlobalVehicle', RemoveGlobalVehicle)
exports('RemoveGlobalObject', RemoveGlobalObject)
exports('RemoveGlobalPlayer', RemoveGlobalPlayer)
exports('SpawnPed', SpawnPed)
exports('DeletePeds', DeletePeds)
exports('GetPeds', function() return Peds end)
exports('AllowTargeting', AllowTargeting)
exports('DisableTarget', disableTarget)
exports('LeftTarget', disableTarget)
exports('RaycastCamera', RaycastCamera)
exports('IsTargetActive', function() return targetActive end)
exports('IsTargetSuccess', function() return menuFocus end)
exports('GetZoneData', function(name) return Zones[name] end)
exports('GetGlobalTypeData', function(t, label)
    for _, o in ipairs(Types[typeNames[t] or t] or {}) do if o.label == label then return o end end
end)

---------------------------------------------------------------- الخيارات المدمجة
local function withControl(veh, fn)
    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local t = GetGameTimer() + 500
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(0) end
    end
    fn()
end

local function isOpen(veh, door) return GetVehicleDoorAngleRatio(veh, door) > 0.05 end
local function unlocked(veh) return GetVehicleDoorLockStatus(veh) < 2 end
local function pct(v) return math.max(0, math.min(100, math.floor(v / 10))) end

local function setDoor(veh, door, open)
    withControl(veh, function()
        if open then SetVehicleDoorOpen(veh, door, false, false) else SetVehicleDoorShut(veh, door, false) end
    end)
end

-- خياران لكل باب (فتح / إغلاق)، ويظهر الخيار المناسب فقط حسب حالة الباب
local function doorOptions(door, name, icon)
    return {
        { num = 1, icon = icon, label = 'فتح ' .. name,
          canInteract = function(veh) return GetIsDoorValid(veh, door) and unlocked(veh) and not isOpen(veh, door) end,
          action = function(veh) setDoor(veh, door, true) end },
        { num = 1, icon = icon, label = 'إغلاق ' .. name,
          canInteract = function(veh) return GetIsDoorValid(veh, door) and isOpen(veh, door) end,
          action = function(veh) setDoor(veh, door, false) end },
    }
end

if Config.VehicleOptions then
    -- الخيار يطلع حسب المكان اللي تأشر عليه بالسيارة
    local doors = {
        { bone = 'door_dside_f', door = 0, name = 'الباب الأمامي', icon = 'fas fa-door-open' },
        { bone = 'door_pside_f', door = 1, name = 'الباب الأمامي', icon = 'fas fa-door-open' },
        { bone = 'door_dside_r', door = 2, name = 'الباب الخلفي', icon = 'fas fa-door-open' },
        { bone = 'door_pside_r', door = 3, name = 'الباب الخلفي', icon = 'fas fa-door-open' },
        { bone = 'boot',         door = 5, name = 'الصندوق',       icon = 'fas fa-box-open' },
        { bone = 'bonnet',       door = 4, name = 'الكبوت',        icon = 'fas fa-car' },
    }
    for _, d in ipairs(doors) do
        AddTargetBone(d.bone, { distance = Config.VehicleDistance or 3.5, options = doorOptions(d.door, d.name, d.icon) })
    end

    AddTargetBone('bonnet', {
        distance = Config.VehicleDistance or 3.5,
        options = {
            { num = 2, icon = 'fas fa-wrench', label = 'حالة المركبة',
              action = function(veh)
                  QBCore.Functions.Notify(('المحرك: %d%% | الهيكل: %d%% | الوقود: %d%%'):format(
                      pct(GetVehicleEngineHealth(veh)), pct(GetVehicleBodyHealth(veh)), math.floor(GetVehicleFuelLevel(veh))), 'primary', 5000)
              end },
        },
    })
end

if Config.Search.enabled then
    AddGlobalPlayer({
        distance = Config.Search.maxDistance,
        options = {
            { icon = 'fas fa-magnifying-glass', label = 'تفتيش', job = Config.Search.allowedJobs,
              action = function(ped)
                  local idx = NetworkGetPlayerIndexFromPed(ped)
                  if idx == -1 then return end
                  TriggerServerEvent('qb-target:searchPlayer', GetPlayerServerId(idx))
              end },
        },
    })
end

if Config.LoginZone.enabled then
    local z = Config.LoginZone
    AddBoxZone('qb-target-login', z.coords, z.length, z.width, {
        heading = z.heading, minZ = z.minZ, maxZ = z.maxZ,
    }, {
        distance = 3.0,
        options = {
            { type = 'server', event = 'qb-target:takejob', icon = 'fas fa-user-shield', label = z.label },
        },
    })
end

RegisterNetEvent('qb-target:searchResult', function(info)
    QBCore.Functions.Notify(('نتيجة التفتيش — كاش: $%s | البنك: $%s'):format(info.cash, info.bank), 'primary', 6000)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if targetActive then SetNuiFocus(false, false) end
    DeletePeds()
end)
