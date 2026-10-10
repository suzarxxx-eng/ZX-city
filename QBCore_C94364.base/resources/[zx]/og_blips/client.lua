-- يشيل كل أيقونات الخريطة (الأصلية وأيقونات السكربتات)، ويبقي بس اللي بـ Config.Blips
local MAX_SPRITE = 900
local kept = {} -- [blip handle] = true (أيقوناتنا)

-- العربي يحتاج يمر على support-arabic:escape (يربط الحروف ويلفها بوسم الخط العربي) وإلا يطلع مربعات
local function arabic(text)
    local ok, res = pcall(function() return exports['support-arabic']:escape(text, true) end)
    return (ok and type(res) == 'string' and res ~= '') and res or text
end

local function addBlip(b)
    local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
    SetBlipSprite(blip, b.sprite or 1)
    SetBlipColour(blip, b.color or 0)
    SetBlipScale(blip, b.scale or 0.8)
    -- shortRange = true: بالخريطة المصغرة تظهر بس لمن تقرب منها (ما تلصق بالأطراف)، وبالخريطة الكبيرة تظهر دائماً
    SetBlipDisplay(blip, 2)
    SetBlipAsShortRange(blip, b.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(arabic(b.label or ''))
    EndTextCommandSetBlipName(blip)
    kept[blip] = true
    return blip
end

local saved = {} -- أيقونات أضفتها بـ /blipadd

local function buildOwn()
    for _, b in ipairs(Config.Blips) do addBlip(b) end
end

RegisterNetEvent('og_blips:client:list', function(list)
    for _, blip in ipairs(saved) do kept[blip] = nil RemoveBlip(blip) end
    saved = {}
    for _, b in ipairs(list or {}) do
        saved[#saved + 1] = addBlip({ coords = vector3(b.x, b.y, b.z), sprite = b.sprite, color = b.color, scale = 0.9, label = b.label })
    end
end)

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('og_blips:server:request')
end)

local stats = { found = 0, removed = 0, stubborn = 0 }
local hidden = {} -- أيقونات ما تنحذف: نعيد إخفاءها بسرعة حتى ما يرجعها السكربت

local function sweep()
    stats.found, stats.removed, stats.stubborn = 0, 0, 0
    -- بدونها الـ RemoveBlip ما يشيل إلا أيقونات هذا السكربت (وهذا سبب إن الحذف كان 0)
    SetThisScriptCanRemoveBlipsCreatedByAnyScript(true)
    for sprite = 0, MAX_SPRITE do
        if not Config.KeepSprites[sprite] then
            local blip = GetFirstBlipInfoId(sprite)
            while DoesBlipExist(blip) do
                local nextBlip = GetNextBlipInfoId(sprite)
                if not kept[blip] then
                    stats.found = stats.found + 1
                    RemoveBlip(blip)
                    if DoesBlipExist(blip) then
                        -- أيقونة أصلية ما تنحذف: نخفيها (شفافة + ما تنعرض)
                        stats.stubborn = stats.stubborn + 1
                        hidden[blip] = true
                        SetBlipDisplay(blip, 0)
                        SetBlipAlpha(blip, 0)
                        SetBlipScale(blip, 0.0)
                    else
                        stats.removed = stats.removed + 1
                    end
                end
                blip = nextBlip
            end
        end
    end
end

CreateThread(function()
    Wait(2000)
    buildOwn()
    while true do
        sweep()
        Wait(1500)
    end
end)

-- إعادة الإخفاء السريعة على الأيقونات المخفية (للخريطة المصغرة)
CreateThread(function()
    while true do
        for blip in pairs(hidden) do
            if DoesBlipExist(blip) and not kept[blip] then
                SetBlipDisplay(blip, 0)
                SetBlipAlpha(blip, 0)
                SetBlipScale(blip, 0.0)
            else
                hidden[blip] = nil
            end
        end
        Wait(150)
    end
end)

-- للسكربتات الثانية اللي تريد أيقونتها تبقى: exports['og_blips']:AddBlip({ coords=..., sprite=..., label=... })
exports('AddBlip', addBlip)
exports('RemoveBlip', function(blip)
    kept[blip] = nil
    RemoveBlip(blip)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for blip in pairs(kept) do RemoveBlip(blip) end
end)

-- /blipalphabet: يسوي أيقونة اسمها حروف العربي كلها (كل حرف لحاله)، تفتح الخريطة وتشوف أي حروف تطلع مربع
RegisterCommand('blipalphabet', function()
    local letters = { 'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ة', 'ى', 'ء', 'أ', 'إ', 'آ' }
    local c = GetEntityCoords(PlayerPedId())
    -- كل أيقونة بحرف وحد حتى تشوف كل حرف لحاله بالقائمة
    for i, l in ipairs(letters) do
        addBlip({ coords = vector3(c.x + (i * 2.0), c.y, c.z), sprite = 1, color = 5, scale = 0.6, label = l .. ' ' .. i, shortRange = false })
    end
    TriggerEvent('chat:addMessage', { args = { 'og_blips', 'تم. افتح الخريطة وشوف القائمة، حروف بدون مربع مدعومة' } })
end, false)

-- /blipcount: يطبع كم أيقونة لقى بآخر مسح وكم انحذفت وكم عاندت (انخفت بس)
RegisterCommand('blipcount', function()
    print(('[og_blips] لقى %d | انحذفت %d | عاندت (انخفت) %d'):format(stats.found, stats.removed, stats.stubborn))
    TriggerEvent('chat:addMessage', { args = { 'og_blips', ('لقى %d | انحذفت %d | عاندت %d'):format(stats.found, stats.removed, stats.stubborn) } })
end, false)
