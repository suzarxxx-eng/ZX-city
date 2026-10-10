-- صدى الطلقات + صفير الرصاص (الصوت يتولّد بصفحة html/sound.js)

local function isIndoor(ped)
    return GetInteriorFromEntity(ped) ~= 0
end

local function send(data)
    SendNUIMessage(data)
end

-- أنا أرمي: صدى قريب (جدران) ويكون أقصر داخل المباني
local lastOwn = 0
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if Config.Sound.Echo and IsPedArmed(ped, 4) then
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if now - lastOwn > 120 then
                    lastOwn = now
                    local silenced = IsPedCurrentWeaponSilenced(ped)
                    local indoor = isIndoor(ped)
                    send({
                        type = 'echo',
                        dist = indoor and 0 or Config.Sound.OwnEchoDistance,
                        indoor = indoor,
                        volume = Config.Sound.Volume * (indoor and 0.5 or 0.35) * (silenced and 0.3 or 1.0),
                    })
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- طلقات الغير البعيدة: تنسمع متأخرة وبصدى حسب المسافة
local lastHeard = {}
CreateThread(function()
    while true do
        if Config.Sound.Echo then
            local me = PlayerPedId()
            local myPos = GetEntityCoords(me)
            local now = GetGameTimer()
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= me and IsPedShooting(ped) then
                    local dist = #(GetEntityCoords(ped) - myPos)
                    if dist >= Config.Sound.MinEchoDistance and dist <= Config.Sound.MaxEchoDistance
                        and not IsPedCurrentWeaponSilenced(ped) and now - (lastHeard[ped] or 0) > 150 then
                        lastHeard[ped] = now
                        local fade = 1.0 - (dist - Config.Sound.MinEchoDistance) / (Config.Sound.MaxEchoDistance - Config.Sound.MinEchoDistance)
                        send({
                            type = 'echo',
                            dist = dist,
                            indoor = false,
                            volume = Config.Sound.Volume * 0.45 * math.max(0.15, fade),
                        })
                    end
                end
            end
        end
        Wait(60)
    end
end)

-- صفير رصاصة تعدي قريبة من راسك
local lastWhiz = 0
CreateThread(function()
    while true do
        if Config.Sound.Whiz then
            local me = PlayerPedId()
            local c = GetEntityCoords(me)
            local now = GetGameTimer()
            if now - lastWhiz > 350 and not IsPedShooting(me) and IsBulletInArea(c.x, c.y, c.z + 0.4, Config.Sound.WhizRadius, false) then
                lastWhiz = now
                send({ type = 'whiz', volume = Config.Sound.Volume * 0.8 })
                if Config.Shake then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.03) end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
