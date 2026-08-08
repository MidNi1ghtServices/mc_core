Config = Config or {}

---------------------------------------------------------------
-- MODUL: Moneywash
---------------------------------------------------------------
Config.Moneywash = {
    useOxTarget = true,

    blackMoneyAccount = "black_money",
    cleanMoneyType    = "cash",

    maxActiveJobs = 3,

    minFee = 5,
    maxFee = 50,

    locations = {
        {
            id     = 1,
            label  = "Waschsalon - Innenstadt",
            coords = vector3(471.62, -913.24, 35.97),
            radius = 2.0,
           -- blip   = { enabled = true, sprite = 617, color = 5, scale = 0.8 },
            marker = { r = 9, g = 164, b = 241, alpha = 140 },
        }
    },

    packages = {
        { id = 1, amount = 1000000, fee = 40, time = 10 },
        { id = 2, amount = 500000,  fee = 20, time = 54 },
        { id = 3, amount = 100000,  fee = 35, time = 54 },
    },

    custom = {
        enabled   = true,
        minAmount = 1000,
        maxAmount = 2000000,

        baseTimeMinutes   = 10,
        minutesPerMillion = 40,
        maxTimeMinutes    = 180,

        feeTiers = {
            { upto = 50000,    fee = 5  },
            { upto = 150000,   fee = 12 },
            { upto = 400000,   fee = 20 },
            { upto = 800000,   fee = 30 },
            { upto = 1500000,  fee = 40 },
            { upto = 2000000,  fee = 50 },
        },
    },

    policeNotify = {
        enabled  = true,
        chance   = 60,
        cooldown = 10,
        blipTime = 3,
        jobs     = { "police" },
        blipSprite = 161,
        blipColor  = 1,
        blipLabel  = "Verdächtige Aktivität",
    },
}

