---------------------------------------------------------------
-- MODUL: GiveCar  (eigenstaendige globale Tabelle, wie im Original)
---------------------------------------------------------------
ConfigGiveCar = {
    AdminGroups = {
        ["Owner"] = true,
        ["superadmin"] = true
    },

    Commands = {
        giveCar = "givecar", -- /givecar [ID] [model] [plate(optional)]
        setCar  = "setcar"   -- /setcar [ID] - aktuelles Fahrzeug an Spieler vergeben
    },

    SpawnVehicleOnGive = false,

    AutoPlate = {
        enabled = true,
        prefix = "",
        length = 5
    },

    Logging = {
        enabled = false,
        webhook = "https://ptb.discord.com/api/webhooks/1535235191130554368/KUmwjr9tG1eILhwo8ojyaC9HtJaaQPzBP890MEEZnvyR-L1J0x6NU7MeXmADVM0f-kCr",
        username = "GiveCar Log",
        color = 3066993, -- gruen
        titleGiveCar = "Fahrzeug vergeben",
        titleSetCar = "Fahrzeug vergeben (SetCar)"
    },

    Messages = {
        noPerms = "~r~Du hast keine Berechtigung.",
        usage = "~y~Benutzung: /givecar [ID] [model] [plate(optional)]",
        playerNotFound = "~r~Spieler nicht gefunden.",
        carGivenAdmin = "~g~Fahrzeug vergeben: ~w~%model% (%plate%) → ID %id%",
        carGivenPlayer = "~g~Du hast ein neues Fahrzeug erhalten: ~w~%model% (%plate%)",

        setCarUsage = "~y~Benutzung: /setcar [ID]",
        noVehicle = "~r~Du sitzt in keinem Fahrzeug."
    }
}
