---------------------------------------------------------------
-- MODUL: Kampfunfaehig
---------------------------------------------------------------
Config = Config or {}

Config.Kampfunfaehig = {
    Enabled = true,
    Locale = "DE", -- "DE" oder "EN", siehe Locales weiter unten

    -- Event, das fuer den automatischen Respawn nach Ablauf der
    -- Kampfunfaehigkeit ausgeloest wird
    ReviveEvent = "esx_ambulancejob:revive",

    -- Event, ueber das der Tod/die Kampfunfaehigkeit ausgeloest wird.
    -- Die eigentliche Erkennung laeuft client-seitig ueber IsEntityDead(),
    -- dieses Event wird zusaetzlich gefeuert (z.B. fuer andere Ressourcen).
    DeathEvent = "esx:onPlayerDeath",

    -- Server-seitiges Event, nach dem geprueft wird, ob ein Spieler noch
    -- eine laufende Kampfunfaehigkeit hat (Reconnect / Serverneustart)
    SpawnEvent = "esx:playerLoaded",

    -- Wie lange (ms) nach dem Verbinden gewartet wird, bevor eine laufende
    -- Kampfunfaehigkeit fortgesetzt wird
    SpawnWait = 10000,

    -- Sekunden bis die Kampfunfaehigkeit automatisch endet
    Duration = 80,

    -- Soll der Timer einen Server-Neustart ueberdauern? (wird in der DB
    -- gespeichert und beim naechsten Verbinden fortgesetzt)
    PersistOnRestart = true,

    -- Rundes Ring-Design (html/index.html, #kampfunfaehigApp)
    UseRadialDesign = true,

    -- Nur die Hotbar (Tasten 1-9) waehrend der Kampfunfaehigkeit sperren.
    -- Das Inventar (TAB/I) bleibt weiter benutzbar.
    DisableHotbar = true,

    -- Diese Gruppen bekommen NIE eine Kampfunfaehigkeit
    WhitelistedGroups = {
        ["owner"] = false, -- Beispiel: Owner bewusst NICHT ausgenommen
        ["admin"] = true,
        ["superadmin"] = true
    },

    -- Diese Jobs bekommen NIE eine Kampfunfaehigkeit (z.B. Sanitaeter im Dienst)
    WhitelistedJobs = {
        ["ambulance"] = true
    },

    -- Was passiert, wenn der Timer ablaeuft, ohne dass jemand revived hat?
    -- "auto_respawn"       = Spieler wird automatisch wiederbelebt (ruft ReviveEvent)
    -- "allow_self_respawn" = Spieler bekommt einen Hinweis und kann sich per
    --                        Tastendruck (SelfRespawnKey) selbst wiederbeleben
    OnTimeoutAction = "auto_respawn",
    SelfRespawnKey = 38, -- E (nur bei "allow_self_respawn")

    Hospitals = {
        vec3(298.47, -584.76, 43.26),
    },

    CommandSuggestions = true,

    -- Admin-Befehle. commandName kann frei umbenannt werden, enabled = false
    -- deaktiviert den Befehl komplett.
    Commands = {
        dtstart = {
            enabled = true,
            commandName = "dtstart", -- /dtstart [ID] [Dauer in Sek] [Grund(optional)]
            allowedFromConsole = true,
            enterReason = false, -- false = optional, "must" = Pflicht, true = optional wie false
            allowedWhenDead = false,
            groups = { ["owner"] = true, ["admin"] = true, ["superadmin"] = true }
        },
        dtclear = {
            enabled = true,
            commandName = "dtclear", -- /dtclear [ID] [Grund(optional)]
            allowedFromConsole = true,
            enterReason = false,
            allowedWhenDead = false,
            groups = { ["owner"] = true, ["admin"] = true, ["superadmin"] = true }
        },
        dtclearradius = {
            enabled = true,
            commandName = "dtclearradius", -- /dtclearradius [Radius] [Grund]
            allowedFromConsole = false,
            enterReason = "must", -- Pflichtfeld bei diesem Befehl
            allowedWhenDead = false,
            groups = { ["owner"] = true, ["admin"] = true, ["superadmin"] = true }
        }
    },

    Webhook = {
        Enabled = false,
        Url = ""
    },

    -- HUD-Texte fuer den Ring (html/index.html)
    HudLocale = {
        line1 = "DU BIST NOCH",
        line3 = "KAMPFUNFÄHIG",
        --timeoutNotify = "Du kannst dich jetzt selbst wiederbeleben (Taste E)."
    },

    Locales = {
        ["DE"] = {
            noIdEntered = "Du hast keine ID eingegeben!",
            noDurationEntered = "Du hast keine Dauer eingegeben!",
            noReasonEntered = "Du hast keinen Grund eingegeben!",
            playerNotOnline = "Es gibt keinen online Spieler mit dieser ID!",
            playerNotInDt = "Dieser Spieler ist nicht kampfunfähig!",
            playerAlreadyInDt = "Dieser Spieler ist bereits kampfunfähig!",
            noPermission = "Du hast keine Berechtigung, diesen Befehl zu verwenden!",
            cannotBeUsedByConsole = "Dieser Befehl kann nicht von der Konsole verwendet werden!",
            notAllowedWhenDead = "Dieser Befehl kann nicht verwendet werden, während du kampfunfähig bist.",
            noPlayersNearby = "Keine Spieler mit Kampfunfähigkeit in der Nähe!",

            removedDtRadius = "Du hast die Kampfunfähigkeit von %s Spieler/n erfolgreich entfernt.",
            removedDt = "Du hast die Kampfunfähigkeit von %s erfolgreich entfernt.",
            gotRemovedDt = "Deine Kampfunfähigkeit wurde entfernt.",
            startedDt = "Du hast erfolgreich eine Kampfunfähigkeit für %s gestartet.",
            gotStartedDt = "Du wurdest von einem Admin kampfunfähig gemacht.",

            webhookDtClearConsoleTitle = "Kampfunfähigkeit entfernt (Konsole)",
            webhookDtClearConsoleMsg = "Die Kampfunfähigkeit von **%s** wurde über die Konsole entfernt.\n**Grund:** ```%s```",
            webhookDtClearConsoleMsgNoReason = "Die Kampfunfähigkeit von **%s** wurde über die Konsole entfernt.",

            webhookDtClearClientTitle = "Kampfunfähigkeit entfernt (Client)",
            webhookDtClearClientMsg = "Die Kampfunfähigkeit von **%s** wurde von **%s** entfernt.\n**Grund:** ```%s```",
            webhookDtClearClientMsgNoReason = "Die Kampfunfähigkeit von **%s** wurde von **%s** entfernt.",

            webhookDtClearRadiusClientTitle = "Kampfunfähigkeit im Radius entfernt (Client)",
            webhookDtClearRadiusClientMsg = "Die Kampfunfähigkeit von %s Spieler/n wurde von **%s** entfernt.\n**Koordinaten:** ```%s```\n**Radius:** ```%s```\n**Spieler:** ```%s```\n**Grund:** ```%s```",
            webhookDtClearRadiusClientMsgNoReason = "Die Kampfunfähigkeit von %s Spieler/n wurde von **%s** entfernt.\n**Koordinaten:** ```%s```\n**Radius:** ```%s```\n**Spieler:** ```%s```",

            webhookDtStartConsoleTitle = "Kampfunfähigkeit gestartet (Konsole)",
            webhookDtStartConsoleMsg = "Eine Kampfunfähigkeit von **%s** Sekunden wurde für **%s** über die Konsole gestartet.\n**Grund:** ```%s```",
            webhookDtStartConsoleMsgNoReason = "Eine Kampfunfähigkeit von **%s** Sekunden wurde für **%s** über die Konsole gestartet.",

            webhookDtStartClientTitle = "Kampfunfähigkeit gestartet (Client)",
            webhookDtStartClientMsg = "Eine Kampfunfähigkeit von **%s** Sekunden wurde für **%s** von **%s** gestartet.\n**Grund:** ```%s```",
            webhookDtStartClientMsgNoReason = "Eine Kampfunfähigkeit von **%s** Sekunden wurde für **%s** von **%s** gestartet."
        },

        ["EN"] = {
            noIdEntered = "You did not enter an ID!",
            noDurationEntered = "You did not enter a duration!",
            noReasonEntered = "You did not enter a reason!",
            playerNotOnline = "There is no online player with this ID!",
            playerNotInDt = "This player is not in a deathtimeout!",
            playerAlreadyInDt = "This player already is in a deathtimeout!",
            noPermission = "You are not permitted to use this command!",
            cannotBeUsedByConsole = "This command cannot be used by the console!",
            notAllowedWhenDead = "This command cannot be used while you are unconscious.",
            noPlayersNearby = "No players with deathtimeout nearby!",

            removedDtRadius = "You successfully removed the deathtimeout of %s player/s.",
            removedDt = "You successfully removed the deathtimeout of %s.",
            gotRemovedDt = "Your deathtimeout was removed.",
            startedDt = "You successfully started a deathtimeout for %s.",
            gotStartedDt = "You were incapacitated by an admin.",

            webhookDtClearConsoleTitle = "Deathtimeout cleared (Console)",
            webhookDtClearConsoleMsg = "The deathtimeout of **%s** was cleared via console.\n**Reason:** ```%s```",
            webhookDtClearConsoleMsgNoReason = "The deathtimeout of **%s** was cleared via console.",

            webhookDtClearClientTitle = "Deathtimeout cleared (Client)",
            webhookDtClearClientMsg = "The deathtimeout of **%s** was cleared by **%s**.\n**Reason:** ```%s```",
            webhookDtClearClientMsgNoReason = "The deathtimeout of **%s** was cleared by **%s**.",

            webhookDtClearRadiusClientTitle = "Deathtimeout in radius cleared (Client)",
            webhookDtClearRadiusClientMsg = "The deathtimeout of %s player/s was cleared by **%s**.\n**Coords:** ```%s```\n**Radius:** ```%s```\n**Players:** ```%s```\n**Reason:** ```%s```",
            webhookDtClearRadiusClientMsgNoReason = "The deathtimeout of %s player/s was cleared by **%s**.\n**Coords:** ```%s```\n**Radius:** ```%s```\n**Players:** ```%s```",

            webhookDtStartConsoleTitle = "Deathtimeout started (Console)",
            webhookDtStartConsoleMsg = "A deathtimeout of **%s** seconds was started for **%s** via console.\n**Reason:** ```%s```",
            webhookDtStartConsoleMsgNoReason = "A deathtimeout of **%s** seconds was started for **%s** via console.",

            webhookDtStartClientTitle = "Deathtimeout started (Client)",
            webhookDtStartClientMsg = "A deathtimeout of **%s** seconds was started for **%s** by **%s**.\n**Reason:** ```%s```",
            webhookDtStartClientMsgNoReason = "A deathtimeout of **%s** seconds was started for **%s** by **%s**."
        }
    }
}

-- Uebersetzungs-Helfer: Config.Kampfunfaehig.L("noPermission") -> passender String
-- in der unter Config.Kampfunfaehig.Locale eingestellten Sprache
function Config.Kampfunfaehig.L(key, ...)
    local str = Config.Kampfunfaehig.Locales[Config.Kampfunfaehig.Locale][key]
    if not str then return key end
    if ... then return string.format(str, ...) end
    return str
end

-- Hier lassen sich weitere Bedingungen ergaenzen, unter denen KEINE
-- Kampfunfaehigkeit ausgeloest werden soll (z.B. eigene Minigames/Zonen)
function Config.Kampfunfaehig.CanStart(playerPed)
    -- if exports["deinscript"]:isInZone() then return false end
    return true
end

-- Steuerung, die waehrend der Kampfunfaehigkeit blockiert wird
function Config.Kampfunfaehig.BlockedActions(playerPed)
    DisableControlAction(0, 24, true)  -- Attack
    DisableControlAction(0, 25, true)  -- Aim
    DisableControlAction(0, 37, true)  -- Select Weapon
    DisableControlAction(0, 140, true) -- Melee
    DisableControlAction(0, 141, true) -- Melee Attack Alternate
    DisableControlAction(0, 142, true) -- Melee Attack 2
    DisableControlAction(0, 192, true)
    DisableControlAction(0, 204, true)
    DisableControlAction(0, 211, true)
    DisableControlAction(0, 349, true)

    if IsPedDoingDriveby(playerPed) then
        DisableControlAction(0, 69, true)
        DisableControlAction(0, 92, true)
    end
end
