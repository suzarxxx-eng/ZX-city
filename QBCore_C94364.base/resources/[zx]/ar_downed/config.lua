Config = {}

-- يكتم صوت اللعبة (يطرش) وقت السقوط
Config.MuteWorld = true

-- يكتم أصوات اللاعبين الثانيين (الحجي والراديو) وقت السقوط
Config.MuteVoices = true

-- دقات القلب: تبدي سريعة وتبطى ويا الوقت
Config.Heartbeat = {
    enabled  = true,
    startBpm = 115,
    endBpm   = 42,
    slowDown = 90,   -- خلال كم ثانية توصل لأبطأ دقة
    volume   = 0.9,  -- 0 - 1
}

-- طنين الأذن أول ما يطيح
Config.EarRinging = true

-- غباش الشاشة (0 = بدون، 1 = أقصى)
Config.Blur = 0.55

-- الأزرار المسموحة وقت السقوط (غير المايك)
-- 38 = E (طلب مسعف + الرجوع للمستشفى بعد انتهاء الوقت)
Config.AllowedControls = { 38 }
