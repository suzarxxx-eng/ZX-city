local QBCore = exports['qb-core']:GetCoreObject()
local SHOP = 'og_all_items'

-- يبني "متجر" بي كل أغراض السيرفر ببلاش (الأغراض أول، بعدها الأسلحة)
local function build()
    local list = {}
    for name, it in pairs(QBCore.Shared.Items) do
        if name ~= 'weapon_unarmed' then list[#list + 1] = it end
    end
    table.sort(list, function(a, b)
        local wa, wb = a.type == 'weapon', b.type == 'weapon'
        if wa ~= wb then return wb end
        return a.name < b.name
    end)
    local items = {}
    for _, it in ipairs(list) do
        items[#items + 1] = { name = it.name, price = 0, amount = 999 }
    end
    exports['qb-inventory']:CreateShop({ name = SHOP, label = 'OG - كل الأغراض (' .. #items .. ')', items = items })
end

QBCore.Commands.Add('items', 'قائمة كل أغراض السيرفر (اسحب الغرض لحقيبتك)', {}, false, function(source)
    build() -- كل مرة يتحدث (حتى يرجع العدد كامل)
    exports['qb-inventory']:OpenShop(source, SHOP)
end, 'admin')
