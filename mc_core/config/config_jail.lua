Config = Config or {}

---------------------------------------------------------------
-- MODUL: Jail (esx_jail)
---------------------------------------------------------------
-- Übernommen aus dem eigenständigen "esx_jail"-Script. Original-
-- Abhängigkeiten (es_extended, oxmysql, ox_lib) sind in mc_core
-- bereits vorhanden/geladen.
--
-- KONFLIKT: Das Original nutzte "Config.Locale" als flache
-- Übersetzungstabelle (Config.Locale.arrested, .released, ...).
-- Dieser Name ist in mc_core bereits als String ('de') belegt
-- (siehe Sperrzone/Mechanic-Modul weiter oben). Daher liegt die
-- Jail-Übersetzungstabelle hier unter "Config.JailLocale" -
-- client.lua und server.lua (Jail-Abschnitt) wurden entsprechend
-- darauf umgestellt.

-- Jobs, die grundsätzlich Spieler verhaften dürfen (unabhängig vom Gefängnis)
Config.ArrestJobs = { 'police', 'sheriff' }

-- Maximale Distanz zum Verhaften eines Spielers (/arrest [id])
Config.ArrestDistance = 3.0

-- Wenn true: Waffen werden beim Verhaften automatisch entfernt und bei Entlassung zurückgegeben
Config.RemoveWeaponsOnArrest = true

-- Wenn true: Das komplette Inventar wird beim Verhaften eingezogen und bei Entlassung zurückgegeben
Config.RemoveItemsOnArrest = true

-- Sträflings-Kleidung (ESX Skin - freemode Modelle). enabled=false -> Spieler behält sein Outfit
Config.PrisonClothes = {
    enabled = true,
    male = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 231, ['torso_2'] = 0,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 15,
        ['pants_1'] = 41, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
    },
    female = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 231, ['torso_2'] = 0,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 15,
        ['pants_1'] = 41, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
    }
}

-- Eigenständige, unabhängige Konfiguration für das Admin-Menü (/adminjail, /putinjail).
-- Diese Funktionen umgehen managementJobs/ArrestJobs komplett und werden nur
-- über die hier definierte ESX-Gruppe abgesichert.
Config.AdminJail = {
    enabled = true,                 -- Admin-Jail-System komplett an/aus

    -- Welche ESX-Gruppen (xPlayer.getGroup()) Zugriff auf /adminjail und /putinjail haben.
    admingroups = {
        Owner = true,
    },

    menuCommand = 'adminjail',      -- Befehl zum Öffnen des Admin-Menüs
    consoleCommand = 'putinjail',   -- Chat/Konsolen-Befehl: /putinjail [id] [jailId] [minuten] [grund]

    -- Welche Gefängnisse im Admin-Menü zur Auswahl stehen.
    -- nil / leeres Table = alle Gefängnisse aus Config.Jails werden angeboten.
    allowedJails = nil,

    Position = vector3(1643.65, 2571.32, 45.56),

    -- Schnellauswahl für die Dauer im Menü (in Minuten). "Custom..." erlaubt freie Eingabe.
    durationPresets = { 5, 10, 15, 30, 60, 120, 240 },
    allowCustomDuration = true,

    defaultReason = 'Admin-Sanktion',

    -- Wenn true, wird jede Admin-Aktion zusätzlich im normalen jail_log mit dem Präfix "ADMIN" protokolliert
    logActions = true,

    -- Discord-Webhook für Admin-Jail-Aktionen (optional, leer lassen = deaktiviert)
    webhook = '',
}

-- Du kannst hier so viele Gefängnisse/Zellen anlegen wie du willst.
-- Jedes Gefängnis hat eigene Jobs, die es verwalten dürfen, eigene
-- Zellen-Spawnpunkte, eine Zone (Mittelpunkt + Radius) für den
-- Fluchtalarm sowie eigene Arbeits-/Gym-/Essen-Punkte.
Config.Jails = {
    [1] = {
        label = 'Bolingbroke Penitentiary',
        managementJobs = { 'police', 'sheriff' }, -- wer darf dieses Gefängnis verwalten
        managementPed = { -- Ped an dem das Verwaltungsmenü geöffnet wird
            coords = vector4(1690.87, 2591.2, 45.91, 359.4),
            model = 's_m_m_prisguard_01' -- korrekter GTA-Modellname (nicht s_m_y_prisguard_01!)
        },
        cellSpawns = { -- zufälliger Spawnpunkt für neue Insassen (Option "Zelle" beim Einsperren)
            vector4(1774.92, 2499.71, 45.85, 117.88),
            vector4(1756.27, 2566.06, 45.56, 120.97),
            vector4(1621.59, 2564.19, 45.56, 220.0),
        },
        yardSpawns = { -- zufälliger Spawnpunkt im Gefängnishof (Option "Hof" beim Einsperren)
            vector4(1627.46, 2541.87, 45.56, 215.04),
            vector4(1737.39, 2515.84, 45.56, 256.65),
            vector4(1756.76, 2551.24, 45.56, 335.11),
            vector4(1704.96, 2557.63, 45.55, 79.09),
        },
        releaseCoords = vector4(1846.57, 2585.91, 45.67, 274.68), -- wo Insasse nach Entlassung landet
        zone = {
            center = vector3(1681.53, 2591.61, 45.56),
            radius = 250.0
        },
        workPoints = {
            { label = 'Nummernschilder pressen', coords = vector3(1792.98, 2632.79, 45.56), reward = 3, duration = 8000, cooldown = 90 },
            { label = 'Wäscherei',                coords = vector3(1758.36, 2469.66, 45.56), reward = 2, duration = 6000, cooldown = 60 },
        },
        gymPoints = {
            vector3(1765.10, 2497.10, 45.68),
        },
        foodPoints = {
            vector3(1791.68, 2532.05, 45.55),
        }
    },
    [2] = {
        label = 'LSPD Ausnüchterungszellen',
        managementJobs = { 'police' },
        managementPed = {
            coords = vector4(462.68, -993.35, 30.62, 250.0),
            model = 's_m_y_cop_01'
        },
        cellSpawns = {
            vector4(1846.35, 2585.53, 45.67, 90.0), -- Beispiel: du kannst eigene LSPD-Zellen-Koordinaten eintragen
        },
        yardSpawns = {}, -- kein Hof für die Ausnüchterungszellen -> Auswahl "Hof" fällt automatisch auf cellSpawns zurück
        releaseCoords = vector4(441.60, -982.30, 30.70, 70.0),
        zone = {
            center = vector3(1800.0, 2585.0, 45.0),
            radius = 180.0
        },
        workPoints = {},
        gymPoints = {},
        foodPoints = {}
    }
}

Config.Work = {
    enabled = true,
    -- reward = Minuten, die von der Reststrafe abgezogen werden
    -- duration = Dauer der Fortschrittsanzeige in ms
    -- cooldown = Sekunden bis der gleiche Spieler diesen Job erneut machen darf
}

Config.Bribe = {
    enabled = true,               -- Bestechung komplett an/aus
    requireNearbyGuard = true,    -- ein Wächter (Job aus guardJobs) muss in der Nähe sein
    guardJobs = { 'police', 'sheriff' },
    guardDistance = 3.0,
    cooldown = 300,                -- Sekunden zwischen Versuchen pro Insasse
    cost = 5000,                   -- Preis der Bestechung
    chance = 30,                   -- Erfolgschance in %
    successTimeReduction = 15,     -- Minuten Abzug bei Erfolg
    failPunishment = 10,           -- Minuten Aufschlag bei Misserfolg (0 = keine Strafe)
    notifyGuardsOnAttempt = true,  -- Wächter in der Nähe werden über den Versuch informiert (auch bei Fehlschlag)
}

Config.Escape = {
    enabled = true,
    preventEscape = false,   -- true = Spieler wird zurück in die Zelle teleportiert statt nur Alarm auszulösen
    alertJobs = { 'police', 'sheriff' }, -- wer den Alarm bekommt
    alertCooldown = 60, -- Sekunden zwischen erneuten Alarmen für denselben Insassen
    blipSprite = 60,
    blipColor = 1,

    -- Minispiel-Ausbruch: /ausbrechen startet einen ox_lib Skill-Check. Bei Erfolg
    -- wird der Insasse sofort vollständig entlassen (inkl. Inventar/Waffen zurück,
    -- Teleport zu jail.releaseCoords) - gilt bewusst NUR für das normale Jail-System,
    -- nicht für /adminjail (Admin-Insassen landen nie in ActiveInmates, siehe server.lua).
    minigame = {
        enabled = true,
        command = 'ausbrechen',
        cooldown = 120,                          -- Sekunden zwischen Versuchen (auch nach Fehlschlag)
        difficulty = { 'easy', 'medium', 'hard' }, -- ox_lib skillCheck-Stufen, mehrere = schwerer/mehrstufig
        failPenaltyMinutes = 5,                  -- wird bei Fehlschlag zur Reststrafe addiert (0 = kein Penalty)
    },
}

Config.Food = {
    enabled = true,
    interactDistance = 2.5,
    items = {
        { item = 'sandwich', label = 'Essen geben',   hunger = 30 },
        { item = 'water',    label = 'Wasser geben',  thirst = 30 },
    }
}

Config.Gym = {
    enabled = true,
    duration = 15000,   -- ms Trainingsdauer
    cooldown = 300,     -- Sekunden Cooldown
    animDict = 'amb@world_human_muscle_flex@male@base',
    anim = 'base',
}

Config.LogEntriesPerPage = 30

-- Umbenannt von "Config.Locale" (siehe Konflikt-Hinweis oben)
Config.JailLocale = {
    arrested       = 'Du wurdest verhaftet und wanderst für %s Minute(n) ins Gefängnis (%s).',
    released       = 'Du wurdest aus dem Gefängnis entlassen.',
    not_allowed_job = 'Du hast nicht den nötigen Job dafür.',
    player_not_found = 'Spieler nicht gefunden oder zu weit entfernt.',
    time_updated   = 'Reststrafe aktualisiert.',
    work_done      = 'Gute Arbeit! Deine Reststrafe wurde um %s Minute(n) reduziert.',
    work_cooldown  = 'Du musst dich erst ausruhen, bevor du das wieder tun kannst.',
    bribe_success  = 'Der Wächter lässt sich überzeugen. Deine Strafe wurde um %s Minute(n) reduziert.',
    bribe_fail     = 'Der Wächter lässt sich nicht bestechen! Deine Strafe wurde um %s Minute(n) erhöht.',
    bribe_no_guard = 'Kein Wächter in der Nähe.',
    bribe_no_money = 'Du hast nicht genug Geld für den Bestechungsversuch.',
    bribe_cooldown = 'Du musst warten, bevor du es erneut versuchen kannst.',
    escape_alert   = 'Fluchtalarm! Ein Insasse versucht aus %s zu fliehen!',
    food_given     = 'Du hast dem Insassen etwas gegeben.',
}

