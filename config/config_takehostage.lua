Config = Config or {}

---------------------------------------------------------------
-- MODUL: TakeHostage
---------------------------------------------------------------
Config.TakeHostage = {
    enabled = true,             -- an/aus
    command = 'takehostage',    -- Haupt-Befehl
    shortCommand = 'th',        -- Kurzform des Befehls
    maxDistance = 3.0,          -- wie nah man dran sein muss
    allowedWeapons = {          -- Waffen, mit denen man jemanden als Geisel nehmen kann
        -- HasPedGotWeapon()/GetAmmoInPedWeapon() erwarten ebenfalls einen Hash, kein String.
        GetHashKey("WEAPON_PISTOL"),
        GetHashKey("WEAPON_COMBATPISTOL"),
        -- weitere Waffen hier ergänzen
    },
}

