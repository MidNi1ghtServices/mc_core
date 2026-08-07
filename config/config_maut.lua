---------------------------------------------------------------
-- MODUL: Maut  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
-- Server kann darüber jede Notify anzeigen lassen, läuft durch MC_Notify (Auto-Detect)
RegisterNetEvent("mc_core:notifyClient")
AddEventHandler("mc_core:notifyClient", function(title, msg, ntype, duration)
    MC_Notify(title, msg, ntype, duration)
end)

MautConfig = {
    Price = 500,
    SpeedFactor = 6.0,
    HighSpeedBase = 10000,
    UseBank = true,

    FreeJobs = {
        police = false,
        fib = true,
        ambulance = true,
    },

    -- WICHTIG: gilt ab dem Moment, in dem die Zone VERLASSEN wird (nicht ab
    -- der Bezahlung). Solange man in der Zone steht, greift ohnehin die
    -- harte Sperre (MautActive) - da wird niemals doppelt abgerechnet.
    -- Vorher stand hier "1" statt "120" (Kommentar sagte 2 Minuten, tatsächlich
    -- aktiv war aber nur 1 Sekunde) -> dadurch kam Geld+Notify quasi sofort
    -- wieder, sobald man kurz aus der Zone raus und wieder rein war.
    Cooldown = 3, -- Sekunden Wartezeit NACH Verlassen der Zone, bevor an derselben Mautstelle wieder abgebucht werden kann

    Tolls = {
        { coords = vector3(-2698.93, 2358.39, 16.83), radius = 20.0, name = "Great Ocean Highway Maut" },   
        { coords = vector3(-1328.21, 2459.62, 25.75), radius = 10.0, name = "route 68 3 Maut" },  
        { coords = vector3(-473.39, 2821.08, 36.83), radius = 10.0, name = "route 68 2 Maut" },
        { coords = vector3(-435.04, 2819.35, 38.75), radius = 10.0, name = "route 68 1 Maut" },
        { coords = vector3(225.5, 2487.45, 54.98), radius = 10.0, name = "Senora Road Sand weg Maut" },
        { coords = vector3(340.13, 2538.65, 44.42), radius = 10.0, name = "Senora Road Maut" },
        { coords = vector3(1962.2, 2624.93, 45.98), radius = 10.0, name = "Senora Freeway SG Maut" },
        { coords = vector3(2012.8, 2580.3, 54.6), radius = 10.0, name = "Senora Freeway Maut" },
        { coords = vector3(2056.4, 2537.33, 57.31), radius = 10.0, name = "Senora Freeway zug  Maut" },
        { coords = vector3(2157.87, 2447.29, 89.08), radius = 10.0, name = "Senora Way sand weg Maut" },
        { coords = vector3(2542.02, 2104.3, 19.62), radius = 10.0, name = "Senora Way Maut" }
    },

    Webhook = "https://ptb.discord.com/api/webhooks/1528903129339400376/-C6BQVA6OEXc3DYFLKJ333kPW0zDq0o5Jc4s0CbU31hFa25aP9Q9zLjfD5BR01ZJoDVF"
}

