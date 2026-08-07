Config = Config or {}

---------------------------------------------------------------
-- MODUL: Revive
---------------------------------------------------------------
Config.Revive = {

    Price = 2500,
    UseBank = true,
    Countdown = 300, -- 5 Minuten

    Blips = {
        enabled = true,
        name = "Revive Station",
        sprite = 153,     -- Medic Herz
        color = 1,        -- Rot
        scale = 0.9
    },

    Marker = {
        enabled = true,
        type = 2,          -- 1 = vertical, 2 = horizontal circle
        size = vector3(0.5, 0.5, 0.5),
        color = { r = 255, g = 0, b = 0, a = 180 }, -- Rot WS-Style
        rotate = false
    },

    Stations = {
        { coords = vector3(300.26, -578.82, 44.26), heading = 72.1 },
        { coords = vector3(1839.0, 3672.0, 34.28), heading = 210.0 }
    },

    -- DISCORD WEBHOOK
    Discord = {
        enabled = true,
        servername = "web.services.io",
        url = "https://web-services.io/",
        icon = "https://tobias.isfucking.pro/4zzE5A.png",
        color = "3447003",
        username = "MC - REVIVESTATION",
        webhook = "https://ptb.discord.com/api/webhooks/1525546367718789140/-TkF6elMoScwB3CytKoXP12fa8ZiPcMZLv4bChb4-6CQwHM9aSGH_RdAuyUSmt32YBEp"
    }

}

