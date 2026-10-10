Config = {}

-- Sprint stamina
Config.Stamina = {
    enabled = true,
    exhaustBelow = 8.0,       -- % stamina: sprint is blocked below this
    recoverAbove = 35.0,      -- % stamina needed before sprint is allowed again
    heavyWeaponDrain = 0.12,  -- extra % stamina drained per tick while sprinting with a heavy weapon out
    armorDrain = 0.05,        -- extra drain per tick while wearing body armor
    tickMs = 100,
}

-- Jumping
Config.Jump = {
    enabled = true,
    cooldownMs = 1600,        -- time between jumps (stops bunny-hopping)
    staminaCost = 6.0,        -- % stamina removed per jump
    blockWhenExhausted = true,
}

-- Falls
Config.Fall = {
    enabled = true,
    ragdollHeight = 3.0,      -- meters fallen before the player stumbles/ragdolls on landing
    damagePerMeter = 6,       -- extra health lost per meter above ragdollHeight (0 to disable)
    maxRagdollMs = 3500,
}

-- Stumbling (rare trip while sprinting when badly hurt or exhausted)
Config.Stumble = {
    enabled = true,
    healthBelowPct = 35,      -- % of max health
    chancePerSecond = 0.04,   -- 4% each second while sprinting under that health
    ragdollMs = 1500,
}

-- Weapon groups counted as "heavy" (rifles, shotguns, MGs, launchers, heavy)
Config.HeavyGroups = {
    [GetHashKey('GROUP_RIFLE')] = true,
    [GetHashKey('GROUP_SHOTGUN')] = true,
    [GetHashKey('GROUP_MG')] = true,
    [GetHashKey('GROUP_SNIPER')] = true,
    [GetHashKey('GROUP_HEAVY')] = true,
}
