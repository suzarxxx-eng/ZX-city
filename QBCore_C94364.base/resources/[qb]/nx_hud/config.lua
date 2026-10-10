Config = {}

-- 'auto' detects qb-core / es_extended, otherwise runs standalone.
-- Options: 'auto' | 'qb' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- Default key for the settings menu. Players can rebind it in
-- Settings > Key Bindings > FiveM. Only applies the first time they join.
Config.OpenKey = 'U'
Config.SeatbeltKey = 'B'

-- Loop intervals in ms. Higher = cheaper, lower = smoother.
-- Only changed values are sent to the NUI, so these loops stay cheap.
Config.StatusInterval = 250   -- on-foot stats
Config.VehicleInterval = 60   -- speedometer while driving (idle loop sleeps 500ms)

Config.HideMinimap = true     -- always hide the GTA minimap/radar

Config.MaxSpeedKmh = 280     -- full-scale value of the speed arc

-- Seatbelt
Config.SeatbeltWarnSpeed = 25 -- km/h above which the unbuckled warning starts
Config.EjectOnCrash = false   -- throw unbuckled players through the windshield on a hard stop
Config.EjectDecel = 70        -- km/h lost within one VehicleInterval tick to count as a crash

-- Duty widget. Key = job name, value = label and icon on the badge.
Config.Jobs = {
    police    = { label = 'وزارة الداخلية', icon = '🚓' },
    sheriff   = { label = 'BCSO', icon = '🚓' },
    ambulance = { label = 'EMS',  icon = '🚑' },
    mechanic  = { label = 'MECH', icon = '🔧' },
}
Config.JobRefresh = 15000     -- server recount interval (ms); job/duty changes also trigger a recount

-- ESX has no built-in duty flag. By convention (esx_service) off-duty jobs are
-- named 'off' .. job, e.g. 'offpolice'. Set to nil if your server does it differently.
Config.ESXOffDutyPrefix = 'off'
