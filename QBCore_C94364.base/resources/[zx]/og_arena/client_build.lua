-- أدوات مشتركة: بناء الساحات بالسما + الإنعاش والسلاح (للأرينا والتيد ام)
Build = { objects = {} }

function Build.loadModel(m)
    if not IsModelInCdimage(m) then return false end
    RequestModel(m)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(m)
end

function Build.firstModel(list)
    for _, m in ipairs(list) do if Build.loadModel(m) then return m end end
end

function Build.size(m)
    local mn, mx = GetModelDimensions(m)
    return mx - mn, mn, mx
end

function Build.place(m, x, y, zBottom, heading)
    local _, mn, mx = Build.size(m)
    -- بعض الموديلات مركزها مو بنصها، فنعدل حتى تنرصف صح
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    local r = math.rad(heading or 0.0)
    x = x - (cx * math.cos(r) - cy * math.sin(r))
    y = y - (cx * math.sin(r) + cy * math.cos(r))
    local o = CreateObjectNoOffset(m, x, y, zBottom - mn.z, false, false, false)
    SetEntityHeading(o, heading or 0.0)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    SetEntityLodDist(o, 1500)
    Build.objects[#Build.objects + 1] = o
    return o
end

function Build.clear()
    for _, o in ipairs(Build.objects) do if DoesEntityExist(o) then DeleteObject(o) end end
    Build.objects = {}
end

-- أرضية مستطيلة، ترجع نص العرض ونص الطول الحقيقي
function Build.floor(C, w, l)
    local fm = Build.firstModel(Config.FloorModels)
    if not fm then return w / 2, l / 2 end
    local s = Build.size(fm)
    local nx, ny = math.ceil(w / s.x), math.ceil(l / s.y)
    local x0, y0 = C.x - (nx * s.x) / 2 + s.x / 2, C.y - (ny * s.y) / 2 + s.y / 2
    for i = 0, nx - 1 do
        for j = 0, ny - 1 do Build.place(fm, x0 + i * s.x, y0 + j * s.y, C.z - s.z, 0.0) end
    end
    return nx * s.x / 2, ny * s.y / 2
end

-- جدار حاويات حول الحافة
function Build.walls(C, hw, hl)
    local wm = Build.firstModel(Config.WallModels)
    if not wm then return end
    local s = Build.size(wm)
    local len = math.max(s.x, s.y)
    local along = s.y > s.x and 0.0 or 90.0
    for i = 0, math.ceil(hw * 2 / len) - 1 do
        local t = -hw + len / 2 + i * len
        Build.place(wm, C.x + t, C.y + hl, C.z, along + 90.0)
        Build.place(wm, C.x + t, C.y - hl, C.z, along + 90.0)
    end
    for i = 0, math.ceil(hl * 2 / len) - 1 do
        local t = -hl + len / 2 + i * len
        Build.place(wm, C.x + hw, C.y + t, C.z, along)
        Build.place(wm, C.x - hw, C.y + t, C.z, along)
    end
end

function Build.covers()
    local list = {}
    for _, m in ipairs(Config.CoverModels) do if Build.loadModel(m) then list[#list + 1] = m end end
    return list
end

function Build.weaponOn(ped, w)
    GiveWeaponToPed(ped, w, 250, false, true)
    SetPedInfiniteAmmo(ped, true, w)
    SetCurrentPedWeapon(ped, w, true)
end

function Build.revive()
    TriggerEvent('hospital:client:Revive') -- يرجعه من حالة الإصابة مال qb-ambulancejob بدون مستشفى
    Wait(400)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    end
end

-- ينزل اللاعب بنقطة، ويرجعله الدم والدرع والسلاح وحماية قصيرة
function Build.spawnAt(p, h, weapon, isActive)
    local ped = PlayerPedId()
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    if IsEntityDead(ped) then NetworkResurrectLocalPlayer(p.x, p.y, p.z, h, true, false) ped = PlayerPedId() end
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(ped, h)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, Config.Armor)
    Build.weaponOn(ped, weapon)
    SetEntityInvincible(ped, true)
    SetEntityAlpha(ped, 180, false)
    DoScreenFadeIn(300)
    SetTimeout(Config.SpawnProtect, function()
        if isActive() then SetEntityInvincible(PlayerPedId(), false) ResetEntityAlpha(PlayerPedId()) end
    end)
end

-- يرجع اللاعب لمكانه بالمدينة ويشيل سلاح القتال
function Build.restore(pos, weapon)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local md = exports['qb-core']:GetCoreObject().Functions.GetPlayerData().metadata or {}
    if IsEntityDead(ped) or md.inlaststand or md.isdead then Build.revive() ped = PlayerPedId() end
    if weapon then SetPedInfiniteAmmo(ped, false, weapon) RemoveWeaponFromPed(ped, weapon) end
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    SetEntityInvincible(ped, false)
    ResetEntityAlpha(ped)
    SetPedArmour(ped, 0)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    Build.clear()
    DisplayRadar(true)
    Wait(400)
    DoScreenFadeIn(500)
end
