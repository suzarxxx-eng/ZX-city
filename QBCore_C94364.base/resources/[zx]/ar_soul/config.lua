Config = {}

-- الصلاحية المطلوبة للأوامر (admin أو god)
Config.Permission = 'admin'

-- مدة صعود الروح (ملي ثانية) وارتفاعها (متر)
Config.Duration = 20000
Config.Height = 45.0

-- الروح تطلع نايمة من الجسم وتنعدل واكفة خلال هاي النسبة من المدة (0.3 = أول 30%)
Config.StandUpTime = 0.3

-- أقصى مسافة يشوف منها اللاعبين الروح
Config.ViewDistance = 250.0

-- الأدمن يجهز اللاعب، وإذا ما مات خلال هاي المدة (دقائق) يلغى التجهيز
Config.ArmTimeout = 15

-- شفافية الروح (0 - 255)
Config.GhostAlpha = 150

-- لون الضوء حول الروح
Config.LightColor = { r = 170, g = 210, b = 255 }

-- إعلان بالشات لكل اللاعبين لما تطلع الروح (false للإلغاء)
Config.Announce = true
