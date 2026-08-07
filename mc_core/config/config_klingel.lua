Config = Config or {}

---------------------------------------------------------------
-- MODUL: Klingel
---------------------------------------------------------------
Config.Klingel = {
    Cooldown = 30000, -- (Kommentar im Original: "5 Sekunden" - Wert entspricht aber 30s)

    Jobs = {
        police = {
            label = "LSPD",
            coords = vector3(447.48, -985.54, 30.71),
            sound = "klingel_police",
            notify = "Jemand hat an der Polizeiklingel gedrückt!"
        },
        wolfsbande = {
            label = "207 Wolfsbande",
            coords = vector3(-383.89, 1184.14, 325.68),
            sound = "klingel_police",
            notify = "Jemand hat an der Wolfsklingel gedrückt!"
        },
        ambulance = {
            label = "EMS",
            coords = vector3(-468.74, -1000.78, 23.69),
            sound = "klingel_ems",
            notify = "Jemand hat an der EMS-Klingel gedrückt!"
        },
        fib = {
            label = "FIB",
            coords = vector3(0.0, 0.0, 0.0),
            sound = "klingel_fib",
            notify = "Jemand hat an der FIB-Klingel gedrückt!"
        },
        cartel_de_mardrazo = {
            label = "cartel_de_mardrazo",
            coords = vector3(-2720.49, 1502.19, 106.56),
            sound = "klingel_fib",
            notify = "Jemand hat an der Cartel De Mardrazo-Klingel gedrückt!"
        }
    }
}

