-- og_robberies server: all validation and rewards live here, the client only plays animations/UI.

local Locs = {}               -- [id] = location
for _, l in ipairs(Config.Locations) do Locs[l.id] = l; l.enabled = not Config.OnlyConfiguredSpots end

local CooldownUntil = {}      -- [id] = os.time() when the spot becomes available again
local Busy = {}               -- [id] = src currently robbing it
local Active = {}             -- [src] = { id, token, start, minSeconds }
local LastRequest = {}        -- [src] = GetGameTimer() of last request (anti-spam)

local function notify(src, text, kind)
    TriggerClientEvent('og_robberies:client:notify', src, text, kind or 'info')
end

local function release(src)
    local a = Active[src]
    if not a then return end
    if Busy[a.id] == src then Busy[a.id] = nil end
    Active[src] = nil
end

local function distanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 9999.0 end
    return #(GetEntityCoords(ped) - coords)
end

local function randomToken()
    return ('%x%x%x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff), os.time())
end

local function dispatch(loc)
    if GetResourceState(Config.Police.dispatchResource) ~= 'started' then return end
    pcall(function()
        exports[Config.Police.dispatchResource]:Alert({
            type = 'store',
            coords = loc.coords,
            message = 'نشاط مشبوه / محاولة سرقة',
        })
    end)
end

-- Client asks to start a robbery
RegisterNetEvent('og_robberies:server:start', function(id)
    local src = source
    local loc = type(id) == 'string' and Locs[id]
    if not loc or not loc.enabled then return end

    local now = GetGameTimer()
    if LastRequest[src] and now - LastRequest[src] < Config.AntiSpamMs then
        return notify(src, Config.Text.spam, 'warn')
    end
    LastRequest[src] = now

    if Active[src] then return end
    if distanceTo(src, loc.coords) > Config.ServerMaxDistance then return end
    if Busy[id] then return notify(src, Config.Text.busy, 'warn') end
    if (CooldownUntil[id] or 0) > os.time() then return notify(src, Config.Text.cooldown, 'warn') end
    if loc.minPolice > 0 and Bridge.CountPolice() < loc.minPolice then
        return notify(src, Config.Text.police, 'warn')
    end
    if loc.item and not Bridge.HasItem(src, loc.item) then
        return notify(src, Config.Text.noitem, 'error')
    end

    local token = randomToken()
    local game = {}
    for k, v in pairs(Config.Minigame) do game[k] = v end
    for k, v in pairs(loc.game or {}) do game[k] = v end
    Active[src] = { id = id, token = token, start = os.time(), minSeconds = game.minSeconds }
    Busy[id] = src

    if loc.alertChance > 0 and math.random() < loc.alertChance then dispatch(loc) end

    TriggerClientEvent('og_robberies:client:begin', src, id, token, { pins = game.pins, lives = game.lives, zone = game.zone, speed = game.speed })

    -- safety net: free the spot if the client never finishes
    SetTimeout(game.maxSeconds * 1000, function()
        if Active[src] and Active[src].token == token then release(src) end
    end)
end)

-- Client reports the progress bar finished
RegisterNetEvent('og_robberies:server:finish', function(token)
    local src = source
    local a = Active[src]
    if not a or a.token ~= token then return end
    local loc = Locs[a.id]
    local elapsed = os.time() - a.start

    -- the challenge cannot be solved instantly, and the player must still be at the spot
    if distanceTo(src, loc.coords) > Config.ServerMaxDistance then
        release(src)
        return notify(src, Config.Text.tooFar, 'error')
    end
    if elapsed < a.minSeconds then
        release(src)
        return notify(src, Config.Text.tooFast, 'error')
    end

    release(src)
    CooldownUntil[a.id] = os.time() + loc.cooldown * 60

    if loc.item and math.random() < loc.itemBreak then
        Bridge.RemoveItem(src, loc.item, 1)
    end

    local amount = math.random(loc.reward[1], loc.reward[2])
    Bridge.AddCash(src, amount)
    for _, b in ipairs(Config.BonusItems) do
        if math.random() < b.chance then
            Bridge.AddItem(src, b.item, math.random(b.amount[1], b.amount[2]))
        end
    end
    if Config.Blueprint and math.random() < Config.Blueprint.chance and GetResourceState('og_crafting') == 'started' then
        local ok, bp = pcall(function() return exports['og_crafting']:PickBlueprint(Config.Blueprint.category) end)
        if ok and bp and Bridge.AddItem(src, bp, 1) then
            notify(src, Config.Text.blueprint:format(bp), 'success')
        end
    end
    notify(src, Config.Text.done:format(amount), 'success')
end)

-- Client reports the challenge was failed: the lockpick is always lost, nothing else is given
RegisterNetEvent('og_robberies:server:fail', function(token)
    local src = source
    local a = Active[src]
    if not a or a.token ~= token then return end
    local loc = Locs[a.id]
    release(src)
    if loc.item and Bridge.HasItem(src, loc.item) then
        Bridge.RemoveItem(src, loc.item, 1)
    end
    notify(src, Config.Text.failed, 'error')
end)

RegisterNetEvent('og_robberies:server:cancel', function(token)
    local src = source
    local a = Active[src]
    if a and a.token == token then release(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    release(src)
    LastRequest[src] = nil
end)

-- Admin helper: prints exact coords of where you stand (needs Config.Debug)
RegisterNetEvent('og_robberies:server:coords', function(c)
    local src = source
    if not Config.Debug or not Bridge.IsAdmin(src) then return end
    if type(c) ~= 'table' then return end
    print(('[og_robberies] vec3(%.2f, %.2f, %.2f)'):format(c.x or 0, c.y or 0, c.z or 0))
end)

-- ===== Saved spot positions (set in-game with /rob_setspot <id>) =====
local FILE = 'spots.json'
local function loadOverrides()
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local data = raw and raw ~= '' and json.decode(raw) or {}
    for id, c in pairs(data) do
        if Locs[id] and type(c) == 'table' then Locs[id].coords = vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0); Locs[id].enabled = true end
    end
end
loadOverrides()

local function spotsPayload()
    local out = {}
    for id, l in pairs(Locs) do
        if l.enabled then out[id] = { x = l.coords.x, y = l.coords.y, z = l.coords.z } end
    end
    return out
end

RegisterNetEvent('og_robberies:server:getSpots', function()
    TriggerClientEvent('og_robberies:client:spots', source, spotsPayload())
end)

RegisterCommand('rob_setspot', function(src, args)
    if src == 0 then return end
    if not Bridge.IsAdmin(src) then return notify(src, 'ما عندك صلاحية أدمن', 'error') end
    local id = args[1]
    if not id or not Locs[id] then
        local ids = {}
        for k in pairs(Locs) do ids[#ids + 1] = k end
        table.sort(ids)
        return notify(src, 'استعمل: /rob_setspot ' .. table.concat(ids, ' | '), 'info')
    end
    local p = GetEntityCoords(GetPlayerPed(src))
    -- the ped's origin is ~1m above the floor; store ground level
    Locs[id].coords = vec3(p.x, p.y, p.z - 0.98)
    Locs[id].enabled = true
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local data = raw and raw ~= '' and json.decode(raw) or {}
    data[id] = { x = Locs[id].coords.x, y = Locs[id].coords.y, z = Locs[id].coords.z }
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(data, { indent = true }), -1)
    TriggerClientEvent('og_robberies:client:spots', -1, spotsPayload())
    notify(src, ('تم حفظ مكان %s: %.2f, %.2f, %.2f'):format(id, p.x, p.y, p.z - 0.98), 'success')
    print(('[og_robberies] %s -> vec3(%.2f, %.2f, %.2f)'):format(id, p.x, p.y, p.z - 0.98))
end, false)
RegisterCommand('rob_list', function(src)
    if src ~= 0 and not Bridge.IsAdmin(src) then return end
    for _, l in ipairs(Config.Locations) do
        local line = ('%s  [%s]  %s'):format(l.id, Locs[l.id].enabled and 'ON' or 'غير محدد', l.label)
        if src == 0 then print(line) else notify(src, line, 'info') end
    end
end, false)
