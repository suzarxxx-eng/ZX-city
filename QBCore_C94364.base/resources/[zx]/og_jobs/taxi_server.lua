-- التكسي بين اللاعبين: الزبون يطلب بـ /taxi، وسائق التكسي (موظف على الدوام) يقبل الطلب من التابلت (F6).
-- السيرفر هو اللي يحسب كل شي (المسافة من موقع السيارة، الأجرة، الدفع) ولا يثق بأرقام العميل.
-- الفلوس تنتقل من الزبون للسائق (ما تنطبع فلوس جديدة)، لذلك المستوى يفتح سيارات ومشاوير VIP وخبرة بدون مكافأة دخل.
local QBCore = exports['qb-core']:GetCoreObject()

local JOB = 'taxi'

local Requests = {}   -- [id] = طلب { id, customer, name, pickup, dest, destDist, vip, state, driver, ... }
local ByCustomer = {} -- [src الزبون] = id
local ByDriver = {}   -- [src السائق] = id
local NextId = 0
local PairXp = {}     -- ['سائق:زبون'] = وقت آخر خبرة، ضد التدوير بين حسابين
local CallAt = {}     -- [src] = وقت آخر طلب
local TaxiStats = {}  -- [citizenid] = { trips, earned }

local CALL_COOLDOWN = 15000      -- ملي ثانية بين طلب وطلب لنفس الزبون
local TRACK_EVERY = 4000         -- كل كم نحدّث مكان الطرف الثاني بالخريطة
local MAX_STEP = 90.0            -- أقصى مسافة تنحسب بثانية وحدة (ضد الانتقال الآني)
local PAIR_XP_COOLDOWN = 600000  -- نفس السائق مع نفس الزبون: خبرة مرة كل 10 دقايق
local MIN_XP_DIST = 300.0        -- أقل مسافة حتى تنعطى خبرة

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `og_taxi_stats` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `trips` INT NOT NULL DEFAULT 0,
            `earned` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

---------------------------------------------------------------- أدوات
local function cfg() return Config.Jobs[JOB] end
local function ms() return GetGameTimer() end
local function online(src) return src ~= nil and GetPlayerName(src) ~= nil end
local function notify(src, msg, kind)
    if online(src) then OG.notify(src, msg, kind) end
end

local function send(src, event, ...)
    if online(src) then TriggerClientEvent(event, src, ...) end
end

local function pedOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return ped, GetEntityCoords(ped)
end

local function nameOf(Player, src)
    local ci = Player and Player.PlayerData and Player.PlayerData.charinfo
    if ci and ci.firstname then return ci.firstname .. ' ' .. (ci.lastname or '') end
    return GetPlayerName(src) or '—'
end

local function levelOfPlayer(src)
    local Player = OG.getPlayer(src)
    if not Player then return 1 end
    return OG.levelOf(OG.getXp(Player.PlayerData.citizenid, JOB))
end

local function taxiStats(cid)
    if TaxiStats[cid] then return TaxiStats[cid] end
    local row = MySQL.single.await('SELECT trips, earned FROM og_taxi_stats WHERE citizenid = ?', { cid })
    TaxiStats[cid] = { trips = row and row.trips or 0, earned = row and row.earned or 0 }
    return TaxiStats[cid]
end

local function addTrip(cid, name, paid)
    local st = taxiStats(cid)
    st.trips, st.earned = st.trips + 1, st.earned + paid
    MySQL.update('INSERT INTO og_taxi_stats (citizenid, name, trips, earned) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), trips = VALUES(trips), earned = VALUES(earned)', {
        cid, name, st.trips, st.earned,
    })
end

local function calcFare(j, dist, vip)
    local fare = j.fare.base + dist * j.fare.perMeter
    if vip then fare = fare * (j.vipMultiplier or 1.8) end
    return math.min(math.floor(fare), j.fare.maxFare or 2500)
end

-- السيارة لازم تكون من سيارات الشركة (حسب الموديل). VIP يحتاج سيارة فاخرة
local function vehicleDef(veh)
    local model = GetEntityModel(veh)
    for _, v in ipairs(cfg().vehicles or {}) do
        if joaat(v.model) == model then return v end
    end
end

-- يسحب الأجرة: كاش أول وبعدها بنك. يرجّع المبلغ اللي انسحب فعلاً
local function charge(Player, amount)
    local cash = Player.GetMoney('cash') or 0
    local bank = Player.GetMoney('bank') or 0
    local taken = 0
    local takeCash = math.min(cash, amount)
    if takeCash > 0 and Player.RemoveMoney('cash', takeCash, 'og_jobs-taxi-fare') then taken = taken + takeCash end
    local rest = amount - taken
    if rest > 0 and bank > 0 then
        local takeBank = math.min(bank, rest)
        if Player.RemoveMoney('bank', takeBank, 'og_jobs-taxi-fare') then taken = taken + takeBank end
    end
    return taken
end

---------------------------------------------------------------- إدارة الطلبات
local function closeRequest(req)
    Requests[req.id] = nil
    if ByCustomer[req.customer] == req.id then ByCustomer[req.customer] = nil end
    if req.driver and ByDriver[req.driver] == req.id then ByDriver[req.driver] = nil end
    send(req.customer, 'og_jobs:client:taxiClear')
    send(req.driver, 'og_jobs:client:taxiClear')
end

-- يبلّغ السواقين الفاضيين (وعلى الدوام) بطلب جديد. يرجّع عدد اللي وصلهم
local function dispatch(req)
    local j = cfg()
    local n = 0
    for src, job in pairs(OG.Duty) do
        if job == JOB and online(src) and not ByDriver[src] and src ~= req.customer and not (req.skip and req.skip[src]) then
            if not req.vip or levelOfPlayer(src) >= (j.vipLevel or 3) then
                local _, dc = pedOf(src)
                n = n + 1
                send(src, 'og_jobs:client:taxiRequest', { name = req.name, vip = req.vip, dist = dc and math.floor(#(dc - req.pickup)) or nil })
            end
        end
    end
    return n
end

-- السائق انسحب قبل ما يركب الزبون: نرجّع الطلب للسواقين الثانيين
local function reopen(req, reason)
    if req.driver then
        req.skip = req.skip or {}
        req.skip[req.driver] = true -- السائق اللي انسحب ما يرجع له نفس الطلب
        if ByDriver[req.driver] == req.id then ByDriver[req.driver] = nil end
        send(req.driver, 'og_jobs:client:taxiClear')
    end
    req.driver, req.state, req.createdAt, req.lastTrack, req.acceptedAt = nil, 'open', ms(), nil, nil
    send(req.customer, 'og_jobs:client:taxiClear')
    notify(req.customer, reason .. '، رجّعنا طلبك للسواقين', 'primary')
    dispatch(req)
end

local function giveXp(req, Drv, Cust)
    local j = cfg()
    if (req.dist or 0) < MIN_XP_DIST then return end
    local key = Drv.PlayerData.citizenid .. ':' .. Cust.PlayerData.citizenid
    local t = ms()
    if PairXp[key] and t - PairXp[key] < PAIR_XP_COOLDOWN then return end
    PairXp[key] = t
    OG.addXp(req.driver, Drv, JOB, math.floor(j.fare.xp * (req.vip and 2 or 1)))
end

-- ينهي المشوار ويحاسب الزبون (الدفع يصير بس إذا الزبون ركب ومشى مسافة معقولة)
local function settle(req)
    local j = cfg()
    local riding = req.state == 'riding'
    req.state = 'done' -- حتى ما ينحاسب مرتين
    if riding and j then
        local dist = req.dist or 0
        local Cust, Drv = OG.getPlayer(req.customer), OG.getPlayer(req.driver)
        if dist >= (j.fare.minDistance or 150) and Cust and Drv then
            local fare = calcFare(j, dist, req.vip)
            local paid = charge(Cust, fare)
            if paid > 0 then
                Drv.AddMoney(Config.PayAccount, paid, 'og_jobs-taxi')
                local dcid = Drv.PlayerData.citizenid
                OG.addEarned(dcid, JOB, paid)
                addTrip(dcid, nameOf(Drv, req.driver), paid)
                giveXp(req, Drv, Cust)
                notify(req.customer, ('دفعت $%d للسائق %s (%.1f كم)'):format(paid, nameOf(Drv, req.driver), dist / 1000), 'success')
                notify(req.driver, ('استلمت $%d من %s (%.1f كم)%s'):format(paid, req.name, dist / 1000, paid < fare and ' (كل اللي عنده)' or ''), 'success')
            else
                notify(req.customer, 'ما عندك فلوس تدفع أجرة المشوار', 'error')
                notify(req.driver, 'الزبون ما عنده فلوس، ما انحاسب', 'error')
            end
        else
            notify(req.customer, 'المشوار كان قصير، ما انحاسبت', 'primary')
            notify(req.driver, 'المشوار قصير، ما انحاسب الزبون', 'primary')
        end
    end
    closeRequest(req)
end

local function startRide(req, veh, t)
    req.state = 'riding'
    req.veh = veh
    req.lastPos = GetEntityCoords(veh)
    req.dist = 0.0
    req.startedAt = t
    req.custOut, req.drvOut = 0, 0
    send(req.customer, 'og_jobs:client:taxiTrack', 'clear')
    send(req.driver, 'og_jobs:client:taxiTrack', 'clear')
    notify(req.customer, 'بدأ المشوار، العداد شغال', 'success')
    notify(req.driver, 'الزبون ركب، العداد شغال', 'success')
    if req.dest then send(req.driver, 'og_jobs:client:taxiDest', req.dest.x, req.dest.y) end
end

local function tick(req, t)
    local j = cfg()
    if not j then return closeRequest(req) end

    if not online(req.customer) then
        if req.state == 'riding' then return settle(req) end
        if req.driver then notify(req.driver, 'الزبون طلع من السيرفر', 'primary') end
        return closeRequest(req)
    end

    if req.state == 'open' then
        if t - req.createdAt > (j.requestTtl or 120) * 1000 then
            notify(req.customer, 'ما أحد رد على طلبك، جرب مرة ثانية', 'error')
            closeRequest(req)
        end
        return
    end

    local driver = req.driver
    if not online(driver) or OG.Duty[driver] ~= JOB then
        if req.state == 'riding' then return settle(req) end
        return reopen(req, 'السائق انسحب')
    end

    local cped, ccoords = pedOf(req.customer)
    local dped, dcoords = pedOf(driver)
    if not cped or not dped then return end -- OneSync مطفي: ما نكدر نتتبع المشوار
    local dveh = GetVehiclePedIsIn(dped, false)
    local cveh = GetVehiclePedIsIn(cped, false)

    if req.state == 'accepted' then
        if t - req.acceptedAt > (j.pickupTimeout or 360) * 1000 then
            notify(req.customer, 'تأخر السائق كثير، انلغى الطلب', 'error')
            notify(driver, 'انتهى وقت الوصول للزبون، انلغى المشوار', 'error')
            return closeRequest(req)
        end
        if t - (req.lastTrack or 0) >= TRACK_EVERY then
            req.lastTrack = t
            send(driver, 'og_jobs:client:taxiTrack', 'customer', ccoords.x, ccoords.y, ccoords.z)
            local vc = dveh ~= 0 and GetEntityCoords(dveh) or dcoords
            send(req.customer, 'og_jobs:client:taxiTrack', 'taxi', vc.x, vc.y, vc.z)
        end
        if dveh ~= 0 and cveh == dveh and GetPedInVehicleSeat(dveh, -1) == dped then
            local def = vehicleDef(dveh)
            if not def or (req.vip and not def.vip) then
                if t - (req.warnAt or 0) > 10000 then
                    req.warnAt = t
                    notify(driver, req.vip and 'هذا طلب VIP: لازم سيارة فاخرة أو ليموزين من سيارات الشركة' or 'لازم تسوق سيارة تكسي من سيارات الشركة (استلمها من التابلت)', 'error')
                end
            else
                startRide(req, dveh, t)
            end
        end
        return
    end

    -- riding: المسافة تنحسب من موقع السيارة بالسيرفر
    local veh = req.veh
    if not veh or veh == 0 or not DoesEntityExist(veh) then return settle(req) end
    local pos = GetEntityCoords(veh)
    local step = #(pos - req.lastPos)
    if step <= MAX_STEP then req.dist = req.dist + step end
    req.lastPos = pos

    local custIn = cveh == veh
    local drvIn = dveh == veh and GetPedInVehicleSeat(veh, -1) == dped
    req.custOut = custIn and 0 or (req.custOut + 1)
    req.drvOut = drvIn and 0 or (req.drvOut + 1)
    if req.custOut >= 3 or req.drvOut >= 6 then return settle(req) end

    -- وصلنا للوجهة (إذا الزبون حددها بالخريطة)
    if req.dest and GetEntitySpeed(veh) < 2.0 then
        local dx, dy = pos.x - req.dest.x, pos.y - req.dest.y
        if dx * dx + dy * dy < 35.0 * 35.0 then
            notify(req.customer, 'وصلتم للوجهة', 'success')
            notify(driver, 'وصلتم للوجهة', 'success')
            return settle(req)
        end
    end

    local fare = calcFare(j, req.dist, req.vip)
    -- فلوس الزبون خلصت: نوقف العداد حتى ما يتجاوز اللي يملكه
    local Cust = OG.getPlayer(req.customer)
    if Cust then
        local have = (Cust.GetMoney('cash') or 0) + (Cust.GetMoney('bank') or 0)
        if fare >= have then
            notify(req.customer, 'وصلت أقصى مبلغ تملكه، انتهى المشوار', 'error')
            notify(driver, 'الزبون وصل أقصى مبلغ يملكه، انتهى المشوار', 'primary')
            return settle(req)
        end
    end
    send(req.customer, 'og_jobs:client:taxiMeter', { show = true, fare = fare, dist = req.dist })
    send(driver, 'og_jobs:client:taxiMeter', { show = true, fare = fare, dist = req.dist })
end

CreateThread(function()
    while true do
        Wait(1000)
        local t = ms()
        for _, req in pairs(Requests) do tick(req, t) end
    end
end)

---------------------------------------------------------------- الزبون: طلب وإلغاء
RegisterNetEvent('og_jobs:server:taxiCall', function(vip, dest)
    local src = source
    local j = cfg()
    local Player = OG.getPlayer(src)
    if not j or not Player then return end
    local t = ms()
    if ByCustomer[src] then return notify(src, 'عندك طلب تكسي شغال، الغيه أول بـ /taxicancel', 'error') end
    if ByDriver[src] then return notify(src, 'أنت سائق بمشوار شغال', 'error') end
    if OG.Duty[src] == JOB then return notify(src, 'أنت سائق تكسي على الدوام، ما تكدر تطلب تكسي', 'error') end
    if CallAt[src] and t - CallAt[src] < CALL_COOLDOWN then return notify(src, 'استنى شوي قبل لا تطلب مرة ثانية', 'error') end
    local have = (Player.GetMoney('cash') or 0) + (Player.GetMoney('bank') or 0)
    if have < j.fare.base then return notify(src, ('لازم يكون عندك $%d على الأقل'):format(j.fare.base), 'error') end
    local ped, coords = pedOf(src)
    if not ped then return notify(src, 'ما كدرت أقرا مكانك', 'error') end

    local d
    if type(dest) == 'table' and tonumber(dest.x) and tonumber(dest.y) then
        local dx, dy = tonumber(dest.x), tonumber(dest.y)
        if math.abs(dx) < 9000 and math.abs(dy) < 9000 then d = { x = dx, y = dy } end
    end
    local req = {
        id = NextId + 1, customer = src, name = nameOf(Player, src), pickup = coords, dest = d,
        vip = vip == true, createdAt = t, state = 'open',
    }
    if d then req.destDist = math.sqrt((coords.x - d.x) ^ 2 + (coords.y - d.y) ^ 2) end

    local n = dispatch(req)
    if n == 0 then return notify(src, 'ماكو سواق تكسي متاح هسه' .. (req.vip and ' لمشاوير VIP' or '') .. '، جرب بعد شوي', 'error') end
    NextId = req.id
    Requests[req.id] = req
    ByCustomer[src] = req.id
    CallAt[src] = t
    notify(src, ('تم إرسال طلبك إلى %d سائق، انتظر مكانك%s'):format(n, d and '' or ' (حدد وجهتك بالخريطة قبل الطلب حتى يشوفها السائق)'), 'success')
end)

-- يلغي الطلب: الزبون (قبل أو أثناء المشوار) أو السائق (قبل الركوب يرجع الطلب لغيره، أثناء المشوار ينتهي ويتحاسب)
RegisterNetEvent('og_jobs:server:taxiCancel', function()
    local src = source
    local cid = ByCustomer[src]
    if cid then
        local req = Requests[cid]
        if not req then ByCustomer[src] = nil return end
        if req.state == 'riding' then return settle(req) end
        if req.driver then notify(req.driver, 'الزبون الغى الطلب', 'primary') end
        notify(src, 'انلغى طلب التكسي', 'primary')
        return closeRequest(req)
    end
    local did = ByDriver[src]
    if did then
        local req = Requests[did]
        if not req then ByDriver[src] = nil return end
        if req.state == 'riding' then return settle(req) end
        notify(src, 'الغيت المشوار', 'primary')
        return reopen(req, 'السائق انسحب')
    end
    notify(src, 'ماكو طلب تكسي شغال', 'error')
end)

---------------------------------------------------------------- السائق: قبول وإنهاء واستلام سيارة
RegisterNetEvent('og_jobs:server:taxiAccept', function(id)
    local src = source
    local j = cfg()
    local Player = OG.getPlayer(src)
    if not j or not Player or OG.Duty[src] ~= JOB then return notify(src, 'ابدأ الدوام أول', 'error') end
    if ByDriver[src] then return notify(src, 'عندك مشوار شغال', 'error') end
    local req = Requests[tonumber(id) or -1]
    if not req or req.state ~= 'open' then return notify(src, 'هذا الطلب ما عاد متاح', 'error') end
    if req.customer == src or ByCustomer[src] then return notify(src, 'عندك طلب تكسي شغال كزبون', 'error') end
    if req.skip and req.skip[src] then return notify(src, 'انسحبت من هذا الطلب قبل شوي', 'error') end
    if req.vip and levelOfPlayer(src) < (j.vipLevel or 3) then
        return notify(src, ('مشاوير VIP تحتاج مستوى %d'):format(j.vipLevel or 3), 'error')
    end

    req.state, req.driver, req.acceptedAt, req.lastTrack = 'accepted', src, ms(), nil
    ByDriver[src] = req.id
    local dname = nameOf(Player, src)
    notify(req.customer, ('السائق %s قبل طلبك وجاي لك، انتظر مكانك'):format(dname), 'success')
    notify(src, ('قبلت طلب %s، اتجه له (العلامة الصفراء بالخريطة)'):format(req.name), 'success')
    send(src, 'og_jobs:client:taxiTrack', 'customer', req.pickup.x, req.pickup.y, req.pickup.z)
    send(req.customer, 'og_jobs:client:taxiAssigned', dname)
end)

RegisterNetEvent('og_jobs:server:taxiEnd', function()
    local src = source
    local id = ByDriver[src]
    local req = id and Requests[id]
    if not req then return notify(src, 'ماكو مشوار شغال', 'error') end
    if req.state ~= 'riding' then return notify(src, 'المشوار ما بدأ للحين (الزبون ما ركب)، استخدم إلغاء المشوار', 'error') end
    settle(req)
end)

RegisterNetEvent('og_jobs:server:taxiVehicle', function(job, idx)
    local src = source
    local j = cfg()
    local Player = OG.getPlayer(src)
    if not j or job ~= JOB or not Player or OG.Duty[src] ~= JOB then return notify(src, 'ابدأ الدوام أول', 'error') end
    local v = j.vehicles and j.vehicles[tonumber(idx) or 0]
    if not v then return end
    if levelOfPlayer(src) < v.minLevel then return notify(src, ('هذي السيارة تحتاج مستوى %d'):format(v.minLevel), 'error') end
    if not OG.near(src, j.boss.coords, 60.0) then return notify(src, 'استلم السيارة من عند شركة التكسي', 'error') end
    TriggerClientEvent('og_jobs:client:taxiVehicle', src, tonumber(idx))
end)

-- السائق رجّع السيارة: إذا بمشوار ينتهي (ويتحاسب إذا الزبون كان راكب)
RegisterNetEvent('og_jobs:server:taxiReturned', function()
    OG.taxiAbort(source)
end)

-- السائق ترك الدوام / استقال / تغيّرت وظيفته (يستدعيها server.lua)
OG.taxiAbort = function(src)
    local id = ByDriver[src]
    local req = id and Requests[id]
    if not req then return end
    if req.state == 'riding' then return settle(req) end
    reopen(req, 'السائق ترك الدوام')
end

-- تبديل الشخصية: نفس مصدر اللاعب، فنشيل الدوام والمشاوير
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    -- الحدث يجي والاعب لسا موجود بـ qb-core، فنكدر نحاسب الزبون قبل ما يطلع
    local cid = ByCustomer[src]
    local req = cid and Requests[cid]
    if req then
        if req.state == 'riding' then settle(req)
        else
            if req.driver then notify(req.driver, 'الزبون طلع', 'primary') end
            closeRequest(req)
        end
    end
    if OG.taxiAbort then OG.taxiAbort(src) end
    OG.Duty[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    CallAt[src] = nil
    local cid = ByCustomer[src]
    local req = cid and Requests[cid]
    if req then
        if req.state == 'riding' then settle(req)
        else
            if req.driver then notify(req.driver, 'الزبون طلع من السيرفر', 'primary') end
            closeRequest(req)
        end
    end
    local did = ByDriver[src]
    req = did and Requests[did]
    if req then
        if req.state == 'riding' then settle(req) else reopen(req, 'السائق طلع من السيرفر') end
    end
end)

---------------------------------------------------------------- التابلت (للسائق)
QBCore.Functions.CreateCallback('og_jobs:cb:taxiData', function(src, cb, job)
    local Player = OG.getPlayer(src)
    local j = cfg()
    if not Player or not j or job ~= JOB then return cb(nil) end
    local cid = Player.PlayerData.citizenid
    if OG.employmentOf(cid) ~= JOB then return cb(nil) end
    local xp = OG.getXp(cid, JOB)
    local level = OG.levelOf(xp)
    local st = taxiStats(cid)
    local vipLevel = j.vipLevel or 3
    local _, dc = pedOf(src)
    local t = ms()

    local requests = {}
    for id, req in pairs(Requests) do
        if req.state == 'open' and req.customer ~= src then
            local est
            if req.destDist then
                est = math.floor((j.fare.base + req.destDist * 1.3 * j.fare.perMeter) * (req.vip and (j.vipMultiplier or 1.8) or 1.0))
            end
            requests[#requests + 1] = {
                id = id, name = req.name, vip = req.vip,
                dist = dc and math.floor(#(dc - req.pickup)) or 0,
                destDist = req.destDist and math.floor(req.destDist) or nil, fare = est,
                locked = req.vip and level < vipLevel, minLevel = req.vip and vipLevel or 1,
                age = math.floor((t - req.createdAt) / 1000),
            }
        end
    end
    table.sort(requests, function(a, b) return a.dist < b.dist end)

    local active
    local aid = ByDriver[src]
    local areq = aid and Requests[aid]
    if areq then
        active = {
            state = areq.state, name = areq.name, vip = areq.vip,
            fare = areq.state == 'riding' and calcFare(j, areq.dist or 0, areq.vip) or nil, dist = math.floor(areq.dist or 0),
        }
    end

    local vehicles = {}
    for idx, v in ipairs(j.vehicles or {}) do
        vehicles[#vehicles + 1] = { id = idx, label = v.label, minLevel = v.minLevel, locked = level < v.minLevel, vip = v.vip and true or false }
    end

    local board = MySQL.query.await('SELECT name, trips, earned FROM og_taxi_stats ORDER BY earned DESC LIMIT 10') or {}

    cb({
        level = level, xp = xp, nextXp = OG.nextNeed(level), levels = Config.Levels, bonus = 0,
        trips = st.trips, earned = st.earned, active = active,
        requests = requests, vehicles = vehicles, board = board,
    })
end)
