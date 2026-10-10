local QBCore = exports['qb-core']:GetCoreObject()
local armed = false

---------------------------------------------------------------- مراقبة موت اللاعب المجهز
local function amIDead()
    if IsEntityDead(PlayerPedId()) then return true end
    local ok, pd = pcall(QBCore.Functions.GetPlayerData)
    local md = ok and pd and pd.metadata or {}
    return md.isdead or md.inlaststand or false
end

RegisterNetEvent('ar_soul:client:arm', function()
    if armed then return end
    armed = true
    CreateThread(function()
        while armed do
            if amIDead() then
                armed = false
                TriggerServerEvent('ar_soul:server:died')
                break
            end
            Wait(200)
        end
    end)
end)

RegisterNetEvent('ar_soul:client:disarm', function()
    armed = false
end)

---------------------------------------------------------------- الأدوات
local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(model)
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function loadPtfx(asset)
    RequestNamedPtfxAsset(asset)
    local t = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(10) end
    return HasNamedPtfxAssetLoaded(asset)
end

-- دخان أبيض واقعي (دخان الغاز تبع اللعبة بلون أبيض) يطلع ويختفي لحاله
local function puff(x, y, z, scale, duration)
    if not loadPtfx('core') then return end
    UseParticleFxAssetNextCall('core')
    local fx = StartParticleFxLoopedAtCoord('exp_grd_bzgas_smoke', x, y, z, 0.0, 0.0, 0.0, scale or 1.0, false, false, false, false)
    if not fx or fx == 0 then return end
    SetParticleFxLoopedColour(fx, 1.0, 1.0, 1.0, false)
    SetParticleFxLoopedAlpha(fx, 0.6)
    SetTimeout(duration or 1500, function() StopParticleFxLooped(fx, false) end)
end

-- ضباب أبيض خفيف يلحق الروح وهي تصعد
local function trail(entity)
    if not loadPtfx('core') then return nil end
    UseParticleFxAssetNextCall('core')
    local fx = StartParticleFxLoopedOnEntity('ent_amb_smoke_foundry_white', entity, 0.0, 0.0, -0.6, 0.0, 0.0, 0.0, 0.35, false, false, false)
    if fx and fx ~= 0 then
        SetParticleFxLoopedColour(fx, 1.0, 1.0, 1.0, false)
        SetParticleFxLoopedAlpha(fx, 0.5)
    end
    return fx
end

---------------------------------------------------------------- مشهد صعود الروح
RegisterNetEvent('ar_soul:client:play', function(serverId, coords)
    coords = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(PlayerPedId()) - coords) > Config.ViewDistance then return end

    -- نسخة شفافة من جسم اللاعب (إذا قريب)، وإلا شخصية افتراضية
    local ghost
    local player = GetPlayerFromServerId(serverId)
    local body = player ~= -1 and GetPlayerPed(player) or 0
    if body ~= 0 and DoesEntityExist(body) then
        ghost = ClonePed(body, false, false, true)
    else
        local model = `mp_m_freemode_01`
        if not loadModel(model) then return end
        ghost = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, true)
        SetModelAsNoLongerNeeded(model)
    end
    if not ghost or ghost == 0 then return end

    local baseZ = coords.z
    SetEntityCoordsNoOffset(ghost, coords.x, coords.y, baseZ, false, false, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetBlockingOfNonTemporaryEvents(ghost, true)
    SetPedCanRagdoll(ghost, false)
    SetEntityAlpha(ghost, 0, false)
    if loadDict('random@mugging3') then
        TaskPlayAnim(ghost, 'random@mugging3', 'handsup_standing_base', 2.0, 2.0, -1, 1, 0.0, false, false, false)
    end

    puff(coords.x, coords.y, coords.z - 0.8, 0.5, 2500)
    local mist = trail(ghost)
    if #(GetEntityCoords(PlayerPedId()) - coords) < 40.0 then
        PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)
    end

    local start = GetGameTimer()
    local dur = Config.Duration
    local heading = GetEntityHeading(ghost)
    local c = Config.LightColor

    while true do
        local elapsed = GetGameTimer() - start
        if elapsed >= dur then break end
        local t = elapsed / dur
        -- يبدي بطيء وبعدين يسرع للأعلى
        local z = baseZ + Config.Height * (t * t)
        -- تطلع نايمة من الجسم، وتنعدل واكفة تدريجياً وهي تصعد
        local u = math.min(t / Config.StandUpTime, 1.0)
        local pitch = -90.0 * (1.0 - (1.0 - (1.0 - u) ^ 3))
        if u >= 1.0 then heading = (heading + 0.25) % 360.0 end
        SetEntityCoordsNoOffset(ghost, coords.x, coords.y, z, false, false, false)
        SetEntityRotation(ghost, pitch, 0.0, heading, 2, true)

        -- يظهر تدريجياً بأول ثانيتين، ويختفي بآخر ربع
        local alpha = Config.GhostAlpha
        if elapsed < 2000 then
            alpha = math.floor(Config.GhostAlpha * (elapsed / 2000))
        elseif t > 0.75 then
            alpha = math.floor(Config.GhostAlpha * (1.0 - (t - 0.75) / 0.25))
        end
        SetEntityAlpha(ghost, math.max(0, alpha), false)

        -- هالة ضوء حول الروح
        DrawLightWithRange(coords.x, coords.y, z + 0.9, c.r, c.g, c.b, 5.0, 3.0 * (alpha / 255) + 0.5)

        -- الضباب يخف ويا اختفاء الروح
        if mist then SetParticleFxLoopedAlpha(mist, 0.5 * (alpha / Config.GhostAlpha)) end
        Wait(0)
    end

    if mist then StopParticleFxLooped(mist, false) end
    puff(coords.x, coords.y, baseZ + Config.Height, 0.6, 1200)
    DeleteEntity(ghost)
end)
