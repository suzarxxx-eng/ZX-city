local exhausted = false
local lastJump = 0

local function drainStamina(pct)
    -- RestorePlayerStamina takes a 0-1 fraction; a negative value drains
    RestorePlayerStamina(PlayerId(), -(pct / 100.0))
end

local function hasHeavyWeapon(ped)
    local _, weapon = GetCurrentPedWeapon(ped, true)
    if not weapon or weapon == `WEAPON_UNARMED` then return false end
    return Config.HeavyGroups[GetWeapontypeGroup(weapon)] == true
end

-- Stamina: sprint blocked when exhausted until recovered
CreateThread(function()
    if not Config.Stamina.enabled then return end
    local c = Config.Stamina
    while true do
        Wait(c.tickMs)
        local ped = PlayerPedId()
        -- the native returns stamina *used*, so remaining = 100 - used
        local pct = 100.0 - GetPlayerSprintStaminaRemaining(PlayerId())
        if IsPedSprinting(ped) and not IsPedInAnyVehicle(ped, false) then
            if hasHeavyWeapon(ped) then drainStamina(c.heavyWeaponDrain) end
            if GetPedArmour(ped) > 0 then drainStamina(c.armorDrain) end
        end
        if not exhausted and pct < c.exhaustBelow then
            exhausted = true
            SetPlayerSprint(PlayerId(), false)
        elseif exhausted and pct > c.recoverAbove then
            exhausted = false
            SetPlayerSprint(PlayerId(), true)
        end
    end
end)

-- Jump cooldown / cost
CreateThread(function()
    if not Config.Jump.enabled then return end
    local c = Config.Jump
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsPedJumping(ped) and GetGameTimer() - lastJump > 500 then
            lastJump = GetGameTimer()
            drainStamina(c.staminaCost)
        end
        if GetGameTimer() - lastJump < c.cooldownMs or (c.blockWhenExhausted and exhausted) then
            DisableControlAction(0, 22, true) -- INPUT_JUMP
        end
    end
end)

-- Falls: ragdoll and extra damage on hard landings
CreateThread(function()
    if not Config.Fall.enabled then return end
    local c = Config.Fall
    local peakZ, falling = nil, false
    while true do
        Wait(50)
        local ped = PlayerPedId()
        if IsPedFalling(ped) or IsPedInParachuteFreeFall(ped) then
            local z = GetEntityCoords(ped).z
            if not falling then falling, peakZ = true, z end
            if z > peakZ then peakZ = z end
        elseif falling then
            falling = false
            local dropped = peakZ - GetEntityCoords(ped).z
            peakZ = nil
            if dropped >= c.ragdollHeight and not IsPedInAnyVehicle(ped, false) and not IsPedSwimming(ped) and not IsEntityInWater(ped) then
                local over = dropped - c.ragdollHeight
                local ms = math.min(800 + over * 250, c.maxRagdollMs)
                SetPedToRagdoll(ped, math.floor(ms), math.floor(ms), 0, false, false, false)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                if c.damagePerMeter > 0 then
                    local hp = GetEntityHealth(ped)
                    SetEntityHealth(ped, math.max(hp - math.floor(over * c.damagePerMeter), 1))
                end
            end
        end
    end
end)

-- Stumbling when hurt or exhausted
CreateThread(function()
    if not Config.Stumble.enabled then return end
    local c = Config.Stumble
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedSprinting(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped) then
            local maxHp = GetEntityMaxHealth(ped) - 100
            local hpPct = maxHp > 0 and ((GetEntityHealth(ped) - 100) / maxHp) * 100 or 100
            if (hpPct < c.healthBelowPct or exhausted) and math.random() < c.chancePerSecond then
                SetPedToRagdoll(ped, c.ragdollMs, c.ragdollMs, 0, false, false, false)
            end
        end
    end
end)
