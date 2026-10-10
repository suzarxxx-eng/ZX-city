-- تغويش بسيط وقت إطلاق النار (يستخدم Extra Timecycle حتى ما يتعارض ويا سكربتات ثانية)
local blur = 0.0
local running = false
local MODIFIER = 'hud_def_blur'

local function isDowned()
    return IsEntityDead(PlayerPedId())
end

local function runFade()
    if running then return end
    running = true
    CreateThread(function()
        local last = GetGameTimer()
        SetExtraTimecycleModifier(MODIFIER)
        while blur > 0.01 do
            local now = GetGameTimer()
            local dt = (now - last) / 1000
            last = now
            blur = math.max(0.0, blur - Config.FadeSpeed * dt)
            SetExtraTimecycleModifierStrength(blur)
            Wait(0)
        end
        blur = 0.0
        ClearExtraTimecycleModifier()
        running = false
    end)
end

local function pulse(amount)
    if amount <= 0 or isDowned() then return end
    if amount > blur then blur = math.min(1.0, amount) end
    if Config.Shake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Config.ShakeAmount * amount)
    end
    runFade()
end

-- قوة التغويش حسب المسافة
local function byDistance(dist)
    if dist <= Config.NearDistance then return Config.Nearby end
    if dist >= Config.FarDistance then return 0 end
    local t = (dist - Config.NearDistance) / (Config.FarDistance - Config.NearDistance)
    return Config.Nearby * (1.0 - t)
end

-- التغويش يطلع مرة كل (10 - 15) طلقة بس، مو مع كل طلقة
local function nextEvery()
    return math.random(Config.ShotsEvery.min, Config.ShotsEvery.max)
end
local ownCount, ownTarget, lastShotAt = 0, nextEvery(), 0
local nearCount, nearTarget, lastNearAt = 0, nextEvery(), 0

-- أنا أرمي
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) then
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if now - lastShotAt > 50 then -- طلقة وحدة بس لكل إطار
                    lastShotAt = now
                    ownCount = ownCount + 1
                    if ownCount >= ownTarget then
                        ownCount, ownTarget = 0, nextEvery()
                        local f = IsPedCurrentWeaponSilenced(ped) and Config.SilencedFactor or 1.0
                        pulse(Config.OwnShot * f)
                    end
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- إطلاق نار قريب (لاعبين و NPC)
CreateThread(function()
    while true do
        local me = PlayerPedId()
        local myPos = GetEntityCoords(me)
        local strongest = 0
        for _, ped in ipairs(GetGamePool('CPed')) do
            if ped ~= me and IsPedShooting(ped) then
                local dist = #(GetEntityCoords(ped) - myPos)
                local amount = byDistance(dist)
                if amount > 0 and IsPedCurrentWeaponSilenced(ped) then amount = amount * Config.SilencedFactor end
                if amount > strongest then strongest = amount end
            end
        end
        if strongest > 0 then
            local now = GetGameTimer()
            if now - lastNearAt > 50 then
                lastNearAt = now
                nearCount = nearCount + 1
                if nearCount >= nearTarget then
                    nearCount, nearTarget = 0, nextEvery()
                    pulse(strongest)
                end
            end
        end
        Wait(60)
    end
end)

-- انصبت بطلقة
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim, weapon = args[1], args[7]
    if victim ~= PlayerPedId() then return end
    if weapon and GetWeaponDamageType(weapon) == 3 then -- 3 = رصاص
        pulse(Config.Hit)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ClearExtraTimecycleModifier() end
end)
