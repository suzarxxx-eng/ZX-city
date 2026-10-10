local isMenuOpen = false
local localCallbacks = {}

local function isLoggedIn()
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn then
        return true
    end
    local pData = MTGetPlayerData()
    if pData and (pData.citizenid or pData.cid) then
        return true
    end
    return true -- Fallback to allow opening if in-game
end

-- ============================================================
-- Menu Open / Close Logic
-- ============================================================

local function closeRadialMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ state = "destroy" })
    PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", true)
end

local function isPoliceOrEMS()
    local pData = MTGetPlayerData()
    if pData and pData.job and pData.job.name then
        local j = string.lower(tostring(pData.job.name))
        if j == "police" or j == "ambulance" or j == "sheriff" or j == "ems" then
            return true
        end
    end
    return false
end

local function openRadialMenu()
    print("[mt_radialmenu DEBUG] openRadialMenu called. isLoggedIn:", tostring(isLoggedIn()), "isMenuOpen:", tostring(isMenuOpen))
    if not isLoggedIn() or isMenuOpen then return end

    local isDeadState = MTIsDead()
    if isDeadState and not isPoliceOrEMS() then
        return
    end

    isMenuOpen = true
    local menuStructure = {}
    localCallbacks = {}

    if isDeadState then
        local panicData = Config.SubMenus["police:panic"]
        if panicData and panicData.onSelect then
            localCallbacks["police:panic"] = panicData.onSelect
            table.insert(menuStructure, {
                id = "police:panic",
                title = panicData.title or "PANIC BUTTON",
                icon = panicData.icon or "fa-solid fa-triangle-exclamation",
                close = true,
                functiontype = "local",
                functionName = "police:panic"
            })
        end

        SendNUIMessage({
            state = "show",
            data = menuStructure,
            menuKeyBind = "F1"
        })

        SetCursorLocation(0.5, 0.5)
        SetNuiFocusKeepInput(true)
        SetNuiFocus(true, true)
        PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", true)

        CreateThread(function()
            while isMenuOpen do
                if lib and lib.disableControls then
                    lib.disableControls()
                end
                DisableControlAction(0, 244, true) -- Map / Interaction Menu (M)
                DisableControlAction(0, 199, true) -- Pause Menu
                DisableControlAction(0, 200, true) -- Pause Menu Alt
                Wait(0)
            end
        end)
        return
    end

    for i = 1, #Config.Menu do
        local menuItem = Config.Menu[i]
        if menuItem and (menuItem.enableMenu == nil or menuItem.enableMenu()) then
            local subItems = {}
            local hasSubMenus = menuItem.subMenus and #menuItem.subMenus > 0

            if hasSubMenus then
                for j = 1, #menuItem.subMenus do
                    local subMenuKey = menuItem.subMenus[j]
                    local subMenuData = Config.SubMenus[subMenuKey]

                    if not subMenuData then
                        lib.print.warn(("Radial submenu \"%s\" is not defined in Config.SubMenus"):format(tostring(subMenuKey)))
                    else
                        if subMenuData.enableMenu == nil or subMenuData.enableMenu() then
                            if subMenuData.onSelect then
                                localCallbacks[subMenuKey] = subMenuData.onSelect
                            end

                            local subEntry = {
                                id = subMenuKey,
                                title = subMenuData.title,
                                icon = subMenuData.icon,
                                close = subMenuData.close,
                                functiontype = subMenuData.onSelect and "local" or subMenuData.functiontype,
                                functionParameters = subMenuData.functionParameters,
                                functionName = subMenuData.onSelect and subMenuKey or subMenuData.functionName
                            }
                            table.insert(subItems, subEntry)
                        end
                    end
                end
            end

            if menuItem.onSelect then
                localCallbacks[menuItem.id] = menuItem.onSelect
            end

            local mainEntry = {
                id = menuItem.id,
                title = menuItem.displayName,
                icon = menuItem.icon,
                close = menuItem.close,
                functiontype = menuItem.onSelect and "local" or menuItem.functiontype,
                functionParameters = menuItem.functionParameters,
                functionName = menuItem.onSelect and menuItem.id or menuItem.functionName
            }

            if hasSubMenus then
                mainEntry.items = subItems
            end

            table.insert(menuStructure, mainEntry)
        end
    end

    SendNUIMessage({
        state = "show",
        data = menuStructure,
        menuKeyBind = "F1"
    })

    SetCursorLocation(0.5, 0.5)
    SetNuiFocusKeepInput(true)
    SetNuiFocus(true, true)
    PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", true)

    CreateThread(function()
        while isMenuOpen do
            if lib and lib.disableControls then
                lib.disableControls()
            end
            DisableControlAction(0, 1, true)   -- LookLR
            DisableControlAction(0, 2, true)   -- LookUD
            DisableControlAction(0, 3, true)
            DisableControlAction(0, 4, true)
            DisableControlAction(0, 5, true)
            DisableControlAction(0, 6, true)
            DisableControlAction(1, 1, true)
            DisableControlAction(1, 2, true)
            DisableControlAction(1, 3, true)
            DisableControlAction(1, 4, true)
            DisableControlAction(1, 5, true)
            DisableControlAction(1, 6, true)
            DisableControlAction(0, 30, true)  -- MoveLR
            DisableControlAction(0, 31, true)  -- MoveUD
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 36, true)  -- Duck
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 289, true) -- F2
            DisableControlAction(2, 199, true) -- Pause Menu
            DisableControlAction(0, 245, true) -- Chat
            DisableControlAction(0, 246, true) -- Y
            DisableControlAction(0, 244, true) -- Map / Interaction Menu (M)
            DisableControlAction(0, 200, true) -- Pause Menu Alt
            Wait(0)
        end
    end)
end

-- ============================================================
-- Keybindings & Commands
-- ============================================================

RegisterCommand("+openradial", function()
    openRadialMenu()
end, false)

RegisterCommand("-openradial", function()
    closeRadialMenu()
end, false)

RegisterCommand("radial", function()
    if isMenuOpen then closeRadialMenu() else openRadialMenu() end
end, false)

RegisterKeyMapping("+openradial", "Open Radial Menu", "keyboard", "F1")

RegisterNetEvent("qb-radialmenu:client:open", function()
    openRadialMenu()
end)

RegisterNetEvent("mt_radialmenu:client:open", function()
    openRadialMenu()
end)

-- Radio Handlers
-- قنوات 1-5 للامن العام، 6-10 للإسعاف (والامن العام يكدر يدخلها هم)
local function canUseChannel(channel)
    if channel >= 1 and channel <= 5 then return MTIsPolice() end
    if channel >= 6 and channel <= 10 then return MTIsEMS() or MTIsPolice() end
    return false
end

RegisterNetEvent("qb-radialmenu:client:enter:radio", function(channel)
    channel = tonumber(channel) or 0
    if not canUseChannel(channel) then
        MTNotify('ما عندك صلاحية لهاي القناة', 'error')
        return
    end
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setRadioChannel(channel)
        pcall(function()
            if exports.mt_interface and exports.mt_interface.Notify then
                exports.mt_interface:Notify("Radio", "Connected to Radio Channel " .. channel, "info")
            end
        end)
    end
end)

RegisterNetEvent("qb-radio:cl:ToggleOnOff", function()
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setRadioChannel(0)
        pcall(function()
            if exports.mt_interface and exports.mt_interface.Notify then
                exports.mt_interface:Notify("Radio", "Disconnected from Radio", "info")
            end
        end)
    end
end)

-- إذا تغيرت الوظيفة (طرد / استقالة) يطلع من قناة ما تخصه
RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    if GetResourceState('pma-voice') ~= 'started' then return end
    Wait(200)
    local ok, channel = pcall(function() return LocalPlayer.state.radioChannel end)
    channel = ok and tonumber(channel) or 0
    if channel > 0 and channel <= 10 and not canUseChannel(channel) then
        exports['pma-voice']:setRadioChannel(0)
        MTNotify('تم فصلك من الراديو', 'error')
    end
end)

-- ============================================================
-- Exports & API
-- ============================================================

local function AddOption(optionData)
    table.insert(Config.Menu, optionData)
    return #Config.Menu
end

local function RemoveOption(optionIndex)
    if Config.Menu[optionIndex] then
        table.remove(Config.Menu, optionIndex)
    end
end

exports("AddOption", AddOption)
exports("RemoveOption", RemoveOption)

-- ============================================================
-- NUI Callbacks & Events
-- ============================================================

RegisterNUICallback("closemenu", function(_, cb)
    closeRadialMenu()
    cb("ok")
end)

RegisterNUICallback("triggerAction", function(data, cb)
    PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", true)

    isMenuOpen = false
    SendNUIMessage({ state = "destroy" })
    SetNuiFocusKeepInput(false)

    if data.close == true or data.close == "true" then
        SetNuiFocus(false, false)
    end

    if data.type == "client" then
        TriggerEvent(data.action, data.parameters)
    elseif data.type == "server" then
        TriggerServerEvent(data.action, data.parameters)
    elseif data.type == "local" then
        if localCallbacks[data.action] then
            localCallbacks[data.action]()
        end
    end

    cb("ok")
end)

RegisterNetEvent("qb-radialmenu:client:force:close", closeRadialMenu)
RegisterNetEvent("mt_radialmenu:client:close", closeRadialMenu)
