Config = Config or {}

---------------------------------------------------------------
-- MODUL: Lifeinvader
---------------------------------------------------------------
-- Eigenes Werbescript im "Lifeinvader-Stil": Spieler geben an einem
-- Terminal (Marker) eine Werbung auf, die per Ingame-Benachrichtigung
-- UND als gestylte Einblendung an alle Spieler geht. Preis wahlweise
-- fest oder pro Zeichen. Serverseitig validiert (Länge, verbotene
-- Wörter, Cooldown, Geld) - der Client liefert nur den Text, alles
-- andere (Preis, Berechtigung) entscheidet der Server.
Config.Lifeinvader = {
    enabled = true,

    -- UI
    serverName = 'MC Core',    -- Servername/Branding im UI
    logo = '',                  -- Logo-URL fürs UI (leer = kein Logo, nur Text)

    -- ESX-Anbindung (konfigurierbar, falls z.B. ein Fork von es_extended läuft)
    esxSharedObject = 'es_extended',
    eventPrefix = 'mc_lifeinvader', -- Prefix für alle Events dieses Moduls
    command = 'lifeinvader',        -- optionaler Chat-Befehl zum Öffnen (zusätzlich zum Marker, '' = deaktiviert)

    -- Terminal-Standort
    location = {
        coords = vector3(-1093.98, -251.62, 37.77), -- Beispiel: Lifeinvader HQ, Del Perro
        radius = 2.0,           -- wie nah man dran sein muss, um zu öffnen (Interact-Distanz)
        showDistance = 15.0,    -- ab welcher Distanz Marker/Prompt überhaupt gezeichnet werden (vorher hart einprogrammiert)
        marker = {
            enabled = true,
            type = 36,
            size = { x = 1.0, y = 1.0, z = 1.0 },
            color = { r = 231, g = 76, b = 60, a = 150 },
        },
        blip = {
            enabled = true,
            sprite = 375,
            color = 47,
            scale = 0.8,
            label = 'Lifeinvader',
        },

        -- Optionaler NPC direkt am Terminal (rein optisch/Scenario-Ped, kein Dialog nötig -
        -- man nutzt weiterhin einfach [E] in der Nähe wie beim Marker).
        npc = {
            enabled = false,
            model = 'a_m_m_business_01',
            coords = vector4(-1093.98, -251.62, 36.77, 340.0), -- x, y, z, heading
            scenario = 'WORLD_HUMAN_STAND_MOBILE',
        },
    },

    -- Sound beim Öffnen des Terminals abspielen
    openSound = true,
    openSoundName = 'SELECT',
    openSoundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',

    -- Strukturierte Zusatzfelder (wie im Referenz-Script: Name/Telefonnummer getrennt
    -- von der eigentlichen Nachricht). false = Feld wird im UI gar nicht angezeigt.
    fields = {
        name = true,
        namePlaceholder = 'Name',
        phone = true,
        phonePlaceholder = 'Telefonnummer',
    },

    -- Öffentliche "letzte Werbungen"-Liste im UI (Feed). Läuft rein im Arbeitsspeicher
    -- (kein SQL nötig) - bei Ressourcen-Neustart ist die Liste leer, das ist so gewollt,
    -- da es sich um kurzlebige Werbeanzeigen handelt, keine dauerhaften Datensätze.
    feed = {
        enabled = true,
        maxPosts = 20,        -- älteste wird automatisch verdrängt, sobald mehr als das reinkommen
        maxAgeMinutes = 60,   -- danach wird statt der genauen Zeit nur noch ">60min" angezeigt
    },

    -- QS-Smartphone o.ä.: exportiert eine simple Funktion zum Öffnen aus einem Handy-Script,
    -- ohne dass man physisch am Terminal stehen muss (siehe client.lua -> exports).
    phoneIntegration = {
        enabled = false,
    },

    -- Preisfestlegung: 'fixed' = Config.Lifeinvader.price.fixed,
    -- 'perChar' = Anzahl Zeichen * Config.Lifeinvader.price.perChar
    price = {
        mode = 'fixed',
        fixed = 500,
        perChar = 15,
    },

    maxLength = 140,   -- maximale Zeichenanzahl pro Werbung
    cooldown = 5,      -- Minuten Cooldown zwischen zwei Werbungen (pro Spieler)

    -- Spieler kann im UI wählen, ob sein Name mit veröffentlicht wird.
    allowName = true,          -- Checkbox im UI überhaupt anzeigen (false = immer anonym)
    nameDefault = false,       -- Vorauswahl der Checkbox beim Öffnen
    nameFormat = '%s (von %s)', -- %s Werbetext, %s Spielername - wenn "Mit Namen" gewählt wurde

    -- Wörter/Zeichenfolgen, die in Werbungen nicht erlaubt sind (Groß-/Kleinschreibung egal).
    -- Deckt jetzt auch Links/Attachments/Sonderzeichen ab (Referenz-Script hatte hierfür
    -- eigentlich ZWEI Listen unter demselben Variablennamen "Config.Blacklist" - in Lua
    -- überschreibt die zweite Zuweisung die erste komplett, wodurch "fuck" & Co. in der
    -- Praxis NIE geprüft wurden, nur noch die zweite Liste. Hier bewusst in EINER Liste
    -- zusammengeführt, damit das nicht passieren kann.)
    forbiddenWords = {
        'ADMIN',
        'MODERATOR',
        'SUPPORT',
        'fuck',
        '<',
        '>',
        'https',
        'discord',
        '.com',
        'mp3',
        'mp4',
    },

    -- Soll ein Spieler bei verbotenen Wörtern/Zeichen direkt gekickt werden (statt nur
    -- eine Fehlermeldung zu bekommen)? Entspricht Config.KickByBlacklist im Referenz-Script.
    kickOnForbiddenWord = false,
    kickReason = 'Du wurdest wegen unerlaubter Wörter/Links in einer Lifeinvader-Werbung gekickt.',

    -- Wie lange die Einblendung bei allen Spielern sichtbar bleibt (Sekunden)
    broadcastDuration = 8,

    -- Discord-Webhook für veröffentlichte Werbungen (leer = deaktiviert)
    discord = {
        enabled = false,
        webhook = '',
        botName = 'Lifeinvader',
        color = 15105570, -- rot
        logoUrl = '',          -- eigene Icon-URL fürs Embed. Leer = das mitgelieferte rote "L"-Logo (assets/discord/discord_logo.png) wird automatisch mit hochgeladen.
        progressBarImage = '', -- eigene Bild-URL für den Balken unten im Embed. Leer = der mitgelieferte rote Balken (assets/discord/discord_bar.png) wird automatisch mit hochgeladen.
    },

    -- Admin-Protokoll: eigener, separater Webhook, der JEDEN Versuch loggt (nicht nur
    -- erfolgreiche Werbungen, sondern auch geblockte wegen Blacklist/Cooldown/Geld) -
    -- inklusive Spieler-Identifier, für Moderationszwecke. Läuft komplett unabhängig
    -- vom öffentlichen "discord"-Webhook oben.
    adminDiscord = {
        enabled = false,
        webhook = '',
        botName = 'Lifeinvader Admin-Log',
        color = 15105570,
    },

    -- Alle Texte frei anpassbar. %s wird durch den jeweiligen Wert ersetzt.
    messages = {
        empty = 'Deine Nachricht darf nicht leer sein.',
        tooLong = 'Deine Nachricht ist zu lang (max. %s Zeichen).',
        forbiddenWord = 'Deine Nachricht enthält unerlaubte Wörter.',
        notEnoughMoney = 'Du hast nicht genug Geld (%s$ benötigt).',
        cooldown = 'Du musst noch %s Minute(n) warten, bevor du erneut werben kannst.',
        success = 'Deine Werbung wurde veröffentlicht!',
    },

    notification = {
        title = 'Lifeinvader',
        type = 'success',
    },

    -- Text, der im öffentlichen Discord-Embed als "Name" steht, wenn der Spieler
    -- KEINEN Namen angegeben hat bzw. "Mit Namen versehen" nicht gewählt hat.
    locales = {
        anonymName = 'ANONYM',
    },
}

