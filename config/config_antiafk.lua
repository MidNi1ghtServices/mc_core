Config = Config or {}

---------------------------------------------------------------
-- MODUL: AntiAFK
---------------------------------------------------------------
Config.AFKWebhook = "https://ptb.discord.com/api/webhooks/1532384533775777862/ThzMQljMGZ2eJeqlNmErFe6anwxEcZ1jMzk_vdvKYVhchqfd1tuKuuolrEf-_sunsG4c" -- TODO: eigenen Webhook eintragen
Config.AntiAFK = {
    Enabled = true,              -- System an/aus
    KickAfterMinutes = 30,       -- Nach wie vielen Minuten Inaktivität gekickt wird
    WarnBeforeKick = true,       -- Vorwarnung anzeigen bevor gekickt wird
    WarnSecondsBefore = 60,      -- Wie viele Sekunden vor dem Kick gewarnt wird
    KickMessage = "Du wurdest wegen Inaktivität (AFK) gekickt.",
    WarnMessage = "Du wirst in %d Sekunden wegen AFK gekickt. Bewege dich, um das zu verhindern!",
    CheckIntervalMs = 1000,      -- Wie oft der Client die Bewegung prüft
    MoveThreshold = 0.15,        -- Mindestbewegung in Metern, damit als 'aktiv' gilt
    VelocityThreshold = 0.1,     -- Mindestgeschwindigkeit, damit als 'aktiv' gilt
    CamRayCastDist = 5.0,        -- Reichweite des Kamera-Raycasts (z.B. wenn man umschaut)

    -- Bypass Einstellungen
    Bypass = {
        UseAcePermission = false,       -- z.B. add_ace group.admin mc_core.afkbypass allow
        AcePermission = "mc_core.afkbypass",
        Identifiers = {                -- Alternativ/zusätzlich: feste Liste an Identifiern (license, steam, discord, etc.)
            -- "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        },
        Jobs = {                       -- Jobs, die nie gekickt werden (z.B. Support/Staff-Job)
            -- "admin",
        }
    }
}

