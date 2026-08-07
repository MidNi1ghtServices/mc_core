Config = Config or {}

---------------------------------------------------------------
-- MODUL: AntiVDM
---------------------------------------------------------------
-- FIX: Das Original-Script hat nur EINEN Waffen-Hash (Rammen) auf 0
-- gesetzt. GTA behandelt "vom Auto überfahren werden" aber als eine
-- ZWEITE, eigene Schadensart (WEAPON_RUNOVERBYCAR) - deshalb kam
-- trotzdem noch Schaden durch. Jetzt werden beide abgedeckt.
Config.AntiVDM = {
    enabled = true,             -- an/aus
    weaponHashes = {             -- alle "Fahrzeug-Schaden"-Waffentypen, die auf 0 gesetzt werden
        -- WICHTIG: SetWeaponDamageModifier() erwartet einen Weapon-HASH (Zahl), keinen String!
        -- Das Original nutzte FiveM's Backtick-Hash-Literale (`WEAPON_X`), die nur im
        -- FiveM-eigenen Lua-Runtime gültig sind, aber von Standard-Lua-Tools (z.B. luac)
        -- als Syntaxfehler abgelehnt werden. GetHashKey(...) macht exakt dasselbe, ist
        -- aber überall gültiges Lua.
        GetHashKey("WEAPON_RAMMEDBYCAR"),    -- Schaden durchs Gerammt werden
        GetHashKey("WEAPON_RUNOVERBYCAR"),   -- Schaden durchs Überfahren werden
    },
    damageModifier = 0.0,       -- 0.0 = kein Schaden
}

