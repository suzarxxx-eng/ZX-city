local cam = nil
local charPed = nil
local loadScreenCheckState = false
local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local cached_player_skins = {}

local pendingSkin = nil   -- appearance chosen in the creator, applied once the character is created
local pendingModel = nil
local skin = nil          -- appearance of the preview ped while the creator is open
local creatorGender = 0

local randommodels = { -- models possible to load when choosing empty slot
    'mp_m_freemode_01',
    'mp_f_freemode_01',
}

-- Appearance definitions (keys match qb-clothing's skinData so it can load/save them as-is)

local function defaultSkin()
    local function e(item, texture) return { item = item, texture = texture or 0, defaultItem = item, defaultTexture = texture or 0 } end
    local s = {
        face = e(0), face2 = e(0),
        facemix = { skinMix = 0.5, shapeMix = 0.5, defaultSkinMix = 0.0, defaultShapeMix = 0.0 },
        pants = e(0), hair = e(0), eyebrows = e(-1, 1), beard = e(-1, 1), blush = e(-1, 1), lipstick = e(-1, 1),
        makeup = e(-1, 1), ageing = e(-1), arms = e(0), ['t-shirt'] = e(1), torso2 = e(0), vest = e(0), bag = e(0),
        shoes = e(0), mask = e(0), hat = e(-1), glass = e(-1), ear = e(-1), watch = e(-1), bracelet = e(-1),
        accessory = e(0), decals = e(0), eye_color = e(-1), moles = e(0),
    }
    for _, k in ipairs({ 'nose_0', 'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'cheek_1', 'cheek_2', 'cheek_3',
        'eye_opening', 'lips_thickness', 'jaw_bone_width', 'eyebrown_high', 'eyebrown_forward', 'jaw_bone_back_lenght',
        'chimp_bone_lowering', 'chimp_bone_lenght', 'chimp_bone_width', 'chimp_hole', 'neck_thikness' }) do
        s[k] = e(0)
    end
    return s
end

local Cat = {
    hair = { t = 'comp', id = 2 }, torso2 = { t = 'comp', id = 11 }, ['t-shirt'] = { t = 'comp', id = 8 },
    pants = { t = 'comp', id = 4 }, shoes = { t = 'comp', id = 6 }, arms = { t = 'comp', id = 3 },
    accessory = { t = 'comp', id = 7 }, bag = { t = 'comp', id = 5 }, mask = { t = 'comp', id = 1 },
    beard = { t = 'overlay', id = 1 }, eyebrows = { t = 'overlay', id = 2 }, ageing = { t = 'overlay', id = 3 },
    makeup = { t = 'overlay', id = 4 }, blush = { t = 'overlay', id = 5 }, lipstick = { t = 'overlay', id = 8 },
    hat = { t = 'prop', id = 0 }, glass = { t = 'prop', id = 1 }, ear = { t = 'prop', id = 2 },
    watch = { t = 'prop', id = 6 }, bracelet = { t = 'prop', id = 7 },
    face = { t = 'head' }, face2 = { t = 'head' }, eye_color = { t = 'eye' },
}

local FaceKeys = {
    nose_0 = true, nose_1 = true, nose_2 = true, nose_3 = true, nose_4 = true, nose_5 = true,
    cheek_1 = true, cheek_2 = true, cheek_3 = true, eye_opening = true, lips_thickness = true,
    jaw_bone_width = true, jaw_bone_back_lenght = true, chimp_bone_lowering = true, chimp_bone_lenght = true,
    chimp_bone_width = true, chimp_hole = true, neck_thikness = true, eyebrown_high = true, eyebrown_forward = true,
}

local function itemRange(key)
    local c = Cat[key]
    if c.t == 'comp' then return 0, math.max(GetNumberOfPedDrawableVariations(charPed, c.id) - 1, 0) end
    if c.t == 'overlay' then return -1, math.max(GetPedHeadOverlayNum(c.id) - 1, -1) end
    if c.t == 'prop' then return -1, math.max(GetNumberOfPedPropDrawableVariations(charPed, c.id) - 1, -1) end
    if c.t == 'head' then return 0, 20 end
    return -1, 31 -- eye colour
end

local function textureRange(key)
    local c = Cat[key]
    local it = skin[key].item
    if c.t == 'comp' then
        if key == 'hair' then return 0, GetNumHairColors() - 1 end
        return 0, math.max(GetNumberOfPedTextureVariations(charPed, c.id, it) - 1, 0)
    end
    if c.t == 'overlay' then
        if key == 'ageing' then return 0, 0 end
        return 0, GetNumHairColors() - 1
    end
    if c.t == 'prop' then
        if it < 0 then return 0, 0 end
        return 0, math.max(GetNumberOfPedPropTextureVariations(charPed, c.id, it) - 1, 0)
    end
    if c.t == 'head' then return 0, 20 end
    return 0, 0
end

local function state(key)
    local imin, imax = itemRange(key)
    local tmin, tmax = textureRange(key)
    return { item = skin[key].item, texture = skin[key].texture, minItem = imin, maxItem = imax, minTexture = tmin, maxTexture = tmax }
end

local function wrap(v, lo, hi)
    if hi < lo then return lo end
    if v > hi then return lo end
    if v < lo then return hi end
    return v
end

local function applySkin()
    if charPed and DoesEntityExist(charPed) and skin then
        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, charPed)
    end
end

-- Main Thread

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            TriggerEvent('qb-multicharacter:client:chooseChar')
            return
        end
    end
end)

-- Functions

local function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

local function spawnPreviewPed(model)
    if charPed and DoesEntityExist(charPed) then
        SetEntityAsMissionEntity(charPed, true, true)
        DeleteEntity(charPed)
    end
    loadModel(model)
    local c = Config.PedCoords
    charPed = CreatePed(2, model, c.x, c.y, c.z + 1.0, c.w, false, true)
    SetPedComponentVariation(charPed, 0, 0, 0, 2)
    FreezeEntityPosition(charPed, false)
    SetEntityInvincible(charPed, true)
    PlaceObjectOnGroundProperly(charPed)
    SetBlockingOfNonTemporaryEvents(charPed, true)
    SetEntityHeading(charPed, c.w)
    SetModelAsNoLongerNeeded(model)
end

local function initializePedModel(model, data)
    CreateThread(function()
        if not model then
            model = joaat(randommodels[math.random(#randommodels)])
        end
        spawnPreviewPed(model)
        if data then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', data, charPed)
        end
    end)
end

-- View: zoom 0..1 (full body -> face), height 0..1 (feet -> head), rot = extra degrees the ped is turned
local view = { zoom = 0.0, height = 0.5, rot = 0.0 }
local viewShown = { zoom = 0.0, height = 0.5 }
local camLoop = false

local function lerp(a, b, t) return a + (b - a) * t end

local function placeCam(zoom, height)
    if not cam then return end
    local p = Config.PedCoords
    local h = math.rad(Config.CamHeading)
    local dist = lerp(Config.CamDistance.far, Config.CamDistance.near, zoom)
    local camZ = p.z + lerp(Config.CamHeight.far, Config.CamHeight.near, zoom)
    -- camera sits behind the look direction: forward = (-sin h, cos h)
    local cx = p.x + math.sin(h) * dist
    local cy = p.y - math.cos(h) * dist
    local lookZ = p.z + lerp(0.55, 1.75, height)
    SetCamCoord(cam, cx, cy, camZ)
    PointCamAtCoord(cam, p.x, p.y, lookZ)
    SetCamFov(cam, lerp(48.0, 34.0, zoom))
end

local function resetView()
    view.zoom, view.height, view.rot = 0.0, 0.5, 0.0
    if charPed and DoesEntityExist(charPed) then SetEntityHeading(charPed, Config.PedCoords.w) end
end

local function startCamLoop()
    if camLoop then return end
    camLoop = true
    CreateThread(function()
        while camLoop and cam do
            -- smooth zoom / height so the camera glides instead of snapping
            viewShown.zoom = viewShown.zoom + (view.zoom - viewShown.zoom) * 0.12
            viewShown.height = viewShown.height + (view.height - viewShown.height) * 0.12
            placeCam(viewShown.zoom, viewShown.height)
            if charPed and DoesEntityExist(charPed) then
                local target = (Config.PedCoords.w + view.rot) % 360.0
                local cur = GetEntityHeading(charPed)
                local diff = ((target - cur + 540.0) % 360.0) - 180.0
                SetEntityHeading(charPed, cur + diff * 0.18)
            end
            Wait(0)
        end
        camLoop = false
    end)
end

local function setScene(id)
    local scene = Config.Scenes[1]
    for _, s in ipairs(Config.Scenes) do
        if s.id == id then scene = s end
    end
    NetworkOverrideClockTime(scene.hour, scene.minute, 0)
    SetWeatherTypeNowPersist(scene.weather)
end

local function skyCam(bool)
    TriggerEvent('qb-weathersync:client:DisableSync')
    if bool then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        FreezeEntityPosition(PlayerPedId(), true)
        setScene(Config.Scenes[1].id)
        resetView()
        viewShown.zoom, viewShown.height = 0.0, 0.5
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z + 1.0, 0.0, 0.0, 0.0, 48.0, false, 0)
        placeCam(0.0, 0.5)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 1, true, true)
        startCamLoop()
    else
        camLoop = false
        SetTimecycleModifier('default')
        NetworkClearClockTimeOverride()
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        if cam then SetCamActive(cam, false) DestroyCam(cam, true) end
        cam = nil
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end

local function openCharMenu(bool)
    QBCore.Functions.TriggerCallback('qb-multicharacter:server:GetNumberOfCharacters', function(result, countries)
        local translations = {}
        for k in pairs(Lang.fallback and Lang.fallback.phrases or Lang.phrases) do
            if k:sub(0, ('ui.'):len()) then
                translations[k:sub(('ui.'):len() + 1)] = Lang:t(k)
            end
        end
        SetNuiFocus(bool, bool)
        SendNUIMessage({
            action = 'ui',
            customNationality = Config.customNationality,
            toggle = bool,
            nChar = result,
            enableDeleteButton = Config.EnableDeleteButton,
            translations = translations,
            countries = countries,
            scenes = Config.Scenes,
        })
        skyCam(bool)
        if not loadScreenCheckState then
            ShutdownLoadingScreenNui()
            loadScreenCheckState = true
        end
    end)
end

-- Gives the real player the look chosen in the creator and stores it
local function applyPendingSkin()
    if not pendingSkin then return false end
    local model = pendingModel
    local data = pendingSkin
    pendingSkin, pendingModel = nil, nil
    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    Wait(300)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    TriggerEvent('qb-clothing:client:loadPlayerClothing', data, ped)
    TriggerServerEvent('qb-clothing:saveSkin', model, json.encode(data))
    SetEntityVisible(ped, true)
    return true
end

-- Events

RegisterNetEvent('qb-multicharacter:client:closeNUIdefault', function() -- This event is only for no starting apartments
    DeleteEntity(charPed)
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    Wait(2000)
    skyCam(false)
    local styled = applyPendingSkin()
    SetEntityCoords(PlayerPedId(), Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    Wait(500)
    SetEntityVisible(PlayerPedId(), true)
    Wait(500)
    DoScreenFadeIn(250)
    TriggerEvent('qb-weathersync:client:EnableSync')
    if not styled then
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end
end)

RegisterNetEvent('qb-multicharacter:client:closeNUI', function()
    DeleteEntity(charPed)
    SetNuiFocus(false, false)
    if pendingSkin then
        CreateThread(function()
            skyCam(false)
            applyPendingSkin()
        end)
    end
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    pendingSkin, pendingModel, skin = nil, nil, nil
    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    Wait(1000)
    local ped = PlayerPedId()
    local h = Config.HiddenCoords
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityCoords(ped, h.x, h.y, h.z)
    RequestCollisionAtCoord(Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 8000 do
        Wait(100)
    end
    Wait(1000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    openCharMenu(true)
end)

RegisterNetEvent('qb-multicharacter:client:spawnLastLocation', function(coords, cData)
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent('apartments:client:SetHomeBlip', result.type)
            local ped = PlayerPedId()
            SetEntityCoords(ped, coords.x, coords.y, coords.z)
            SetEntityHeading(ped, coords.w)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true)
            local PlayerData = QBCore.Functions.GetPlayerData()
            local insideMeta = PlayerData.metadata['inside']
            DoScreenFadeOut(500)

            if insideMeta.house then
                TriggerEvent('qb-houses:client:LastLocationHouse', insideMeta.house)
            elseif insideMeta.apartment.apartmentType and insideMeta.apartment.apartmentId then
                TriggerEvent('qb-apartments:client:LastLocationHouse', insideMeta.apartment.apartmentType, insideMeta.apartment.apartmentId)
            else
                SetEntityCoords(ped, coords.x, coords.y, coords.z)
                SetEntityHeading(ped, coords.w)
                FreezeEntityPosition(ped, false)
                SetEntityVisible(ped, true)
            end

            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            Wait(2000)
            DoScreenFadeIn(250)
        end
    end, cData.citizenid)
end)

-- NUI Callbacks

RegisterNUICallback('closeUI', function(_, cb)
    cb('ok')
end)

RegisterNUICallback('disconnectButton', function(_, cb)
    SetEntityAsMissionEntity(charPed, true, true)
    DeleteEntity(charPed)
    TriggerServerEvent('qb-multicharacter:server:disconnect')
    cb('ok')
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local cData = data.cData
    DoScreenFadeOut(10)
    TriggerServerEvent('qb-multicharacter:server:loadUserData', cData)
    openCharMenu(false)
    SetEntityAsMissionEntity(charPed, true, true)
    DeleteEntity(charPed)
    SetEntityVisible(PlayerPedId(), true)
    cb('ok')
end)

RegisterNUICallback('cDataPed', function(nData, cb)
    local cData = nData.cData
    SetEntityAsMissionEntity(charPed, true, true)
    DeleteEntity(charPed)
    if cData ~= nil then
        if not cached_player_skins[cData.citizenid] then
            local temp_model = promise.new()
            local temp_data = promise.new()

            QBCore.Functions.TriggerCallback('qb-multicharacter:server:getSkin', function(model, data)
                temp_model:resolve(model)
                temp_data:resolve(data)
            end, cData.citizenid)

            local resolved_model = Citizen.Await(temp_model)
            local resolved_data = Citizen.Await(temp_data)

            cached_player_skins[cData.citizenid] = { model = resolved_model, data = resolved_data }
        end

        local model = cached_player_skins[cData.citizenid].model
        local data = cached_player_skins[cData.citizenid].data

        model = model ~= nil and tonumber(model) or false

        if model ~= nil and data ~= nil then
            initializePedModel(model, json.decode(data))
        else
            initializePedModel()
        end
        cb('ok')
    else
        initializePedModel()
        cb('ok')
    end
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-multicharacter:server:setupCharacters', function(result)
        cached_player_skins = {}
        SendNUIMessage({
            action = 'setupCharacters',
            characters = result
        })
        cb('ok')
    end)
end)

RegisterNUICallback('removeBlur', function(_, cb)
    SetTimecycleModifier('default')
    cb('ok')
end)

-- Creator

RegisterNUICallback('creatorStart', function(data, cb)
    creatorGender = data.gender == 1 and 1 or 0
    skin = defaultSkin()
    CreateThread(function()
        spawnPreviewPed(joaat(creatorGender == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01'))
        applySkin()
        cb('ok')
    end)
end)

RegisterNUICallback('creatorState', function(data, cb)
    if not skin or not Cat[data.key] then return cb({}) end
    cb(state(data.key))
end)

RegisterNUICallback('creatorStep', function(data, cb)
    local key = data.key
    if not skin or not Cat[key] then return cb({}) end
    local c = Cat[key]
    local delta = tonumber(data.delta) or 0
    if data.field == 'item' then
        local lo, hi = itemRange(key)
        local v = wrap(skin[key].item + delta, lo, hi)
        -- qb-clothing treats prop/eye index 0 as "none", so skip it
        if (c.t == 'prop' or c.t == 'eye') and v == 0 then v = wrap(v + (delta >= 0 and 1 or -1), lo, hi) end
        skin[key].item = v
        -- colours of hair/overlays carry over between styles; clothes reset to their first texture
        if c.t == 'comp' and key ~= 'hair' then
            skin[key].texture = 0
        elseif c.t == 'prop' then
            skin[key].texture = 0
        end
    else
        local lo, hi = textureRange(key)
        skin[key].texture = wrap(skin[key].texture + delta, lo, hi)
    end
    applySkin()
    cb(state(key))
end)

RegisterNUICallback('creatorSlider', function(data, cb)
    if not skin then return cb('ok') end
    local key = data.key
    local value = tonumber(data.value) or 0
    if key == 'shapeMix' or key == 'skinMix' then
        skin.facemix[key] = value
    elseif FaceKeys[key] then
        skin[key].item = math.floor(value)
    end
    applySkin()
    cb('ok')
end)

RegisterNUICallback('creatorRandom', function(_, cb)
    if not skin then return cb({}) end
    for _, key in ipairs({ 'face', 'face2' }) do
        skin[key].item = math.random(0, 20)
        skin[key].texture = math.random(0, 20)
    end
    skin.facemix.shapeMix = math.random() * 0.8 + 0.1
    skin.facemix.skinMix = math.random() * 0.8 + 0.1
    for k in pairs(FaceKeys) do skin[k].item = math.random(-4, 4) end
    for _, key in ipairs({ 'hair', 'torso2', 't-shirt', 'pants', 'shoes' }) do
        local lo, hi = itemRange(key)
        skin[key].item = math.random(lo, hi)
        local tlo, thi = textureRange(key)
        skin[key].texture = math.random(tlo, thi)
    end
    applySkin()
    cb('ok')
end)

RegisterNUICallback('viewSet', function(data, cb)
    if data.zoom ~= nil then view.zoom = math.min(math.max(tonumber(data.zoom) or 0.0, 0.0), 1.0) end
    if data.height ~= nil then view.height = math.min(math.max(tonumber(data.height) or 0.5, 0.0), 1.0) end
    if data.rot ~= nil then view.rot = tonumber(data.rot) or 0.0 end
    cb('ok')
end)

RegisterNUICallback('viewReset', function(_, cb)
    resetView()
    cb({ zoom = view.zoom, height = view.height, rot = view.rot })
end)

RegisterNUICallback('setScene', function(data, cb)
    setScene(data.id)
    cb('ok')
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    local cData = data
    DoScreenFadeOut(150)
    if cData.gender == 'male' or cData.gender == 0 then
        cData.gender = 0
    else
        cData.gender = 1
    end
    if skin then
        pendingSkin = skin
        pendingModel = joaat(cData.gender == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    end
    TriggerServerEvent('qb-multicharacter:server:createCharacter', cData)
    Wait(500)
    cb('ok')
end)

RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('qb-multicharacter:server:deleteCharacter', data.citizenid)
    DeletePed(charPed)
    TriggerEvent('qb-multicharacter:client:chooseChar')
    cb('ok')
end)
