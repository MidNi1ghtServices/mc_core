Config = Config or {}

---------------------------------------------------------------
-- MODUL: Klingel
---------------------------------------------------------------
Config.Klingel = {
    Cooldown = 30000, -- (Kommentar im Original: "5 Sekunden" - Wert entspricht aber 30s)

    -- "job" = tatsaechlicher ESX-Jobname (xPlayer.job.name), der geprueft wird.
    -- Der Tabellen-Key (z.B. "wolfsbande") ist nur ein interner Bezeichner
    -- und muss NICHT mit dem ESX-Jobnamen uebereinstimmen. Bei den Eintraegen
    -- unten bitte "job" pruefen/anpassen, falls der echte ESX-Job anders heisst.
    Jobs = {
        police = {
            label = "LSPD",
            job = "police",
            coords = vector3(447.48, -985.54, 30.71),
            sound = "klingel_police",
            notify = "Jemand hat an der Polizeiklingel gedrückt!"
        },
        wolfsbande = {
            label = "207 Wolfsbande",
            job = "wolfsbande", -- ggf. auf den echten ESX-Jobnamen anpassen
            coords = vector3(-383.89, 1184.14, 325.68),
            sound = "klingel_police",
            notify = "Jemand hat an der Wolfsklingel gedrückt!"
        },
        ambulance = {
            label = "EMS",
            job = "ambulance",
            coords = vector3(-468.74, -1000.78, 23.69),
            sound = "klingel_ems",
            notify = "Jemand hat an der EMS-Klingel gedrückt!"
        },
        fib = {
            label = "FIB",
            job = "fib",
            coords = vector3(0.0, 0.0, 0.0),
            sound = "klingel_fib",
            notify = "Jemand hat an der FIB-Klingel gedrückt!"
        },
        cartel_de_mardrazo = {
            label = "cartel_de_mardrazo",
            job = "cartel_de_mardrazo", -- ggf. auf den echten ESX-Jobnamen anpassen
            coords = vector3(-2720.49, 1502.19, 106.56),
            sound = "klingel_fib",
            notify = "Jemand hat an der Cartel De Mardrazo-Klingel gedrückt!"
        }
    }
}

