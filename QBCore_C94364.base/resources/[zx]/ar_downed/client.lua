local QBCore = exports['qb-core']:GetCoreObject()

local downed = false
local downSince = 0
local audioScene = 'CHARACTER_CHANGE_IN_SKY_SCENE' -- يكتم أصوات العالم
local mutedVoices = {}

---------------------------------------------------------------- هل اللاعب طايح؟
local function isDowned()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return true end
    local ok, pd = pcall(QBCore.Functions.GetPlayerData)
    local md = ok and pd and pd.metadata or {}
    return (md.isdead or md.inlaststand) and true or false
end

---------------------------------------------------------------- الصوت
local function muteVoices(on)
    if not Config.MuteVoices then return end
    if on then
        for _, pl in ipairs(GetActivePlayers()) do
            if pl ~= PlayerId() then
                local sid = GetPlayerServerId(pl)
                MumbleSetVolumeOverrideByServerId(sid, 0.0)
                mutedVoices[sid] = true
            end
        end
    else
        for sid in pairs(mutedVoices) do
            MumbleSetVolumeOverrideByServerId(sid, -1.0)
        end
        mutedVoices = {}
    end
end

local function setDeaf(on)
    if not Config.MuteWorld then return end
    if on then
        if not IsAudioSceneActive(audioScene) then StartAudioScene(audioScene) end
    else
        if IsAudioSceneActive(audioScene) then StopAudioScene(audioScene) end
    end
end

---------------------------------------------------------------- البداية والنهاية
local function startDown()
    downed = true
    downSince = GetGameTimer()
    SendNUIMessage({
        action = 'down',
        state = true,
        heartbeat = Config.Heartbeat,
        ringing = Config.EarRinging,
    })
    setDeaf(true)
    muteVoices(true)
    if Config.Blur > 0 then
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(Config.Blur)
    end
    ShakeGameplayCam('DRUNK_SHAKE', 0.6)
end

local function stopDown()
    downed = false
    SendNUIMessage({ action = 'down', state = false })
    setDeaf(false)
    muteVoices(false)
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
end

---------------------------------------------------------------- المراقبة
CreateThread(function()
    while true do
        local now = isDowned()
        if now and not downed then
            startDown()
        elseif not now and downed then
            stopDown()
        end
        Wait(250)
    end
end)

-- وقت السقوط: كل الأزرار مقفولة إلا المايك (249) والمسموحة بالإعدادات
CreateThread(function()
    local refresh = 0
    while true do
        if downed then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            EnableControlAction(0, 249, true) -- المايك (Push to talk)
            for _, c in ipairs(Config.AllowedControls) do EnableControlAction(0, c, true) end
            HideHudAndRadarThisFrame()

            -- لاعبين جدد يدخلون المنطقة ينكتمون هم
            if GetGameTimer() > refresh then
                refresh = GetGameTimer() + 300
                muteVoices(true)
                setDeaf(true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- نصوص الإسعاف بالعربي (يرسلها qb-ambulancejob: الوقت، الرجوع، طلب المسعف)
AddEventHandler('ar_downed:client:info', function(info)
    SendNUIMessage({ action = 'info', info = info })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and downed then stopDown() end
end)
