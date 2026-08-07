---------------------------------------------------------------
-- MODUL: Fraktionssperre  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
FraksperreConfig = {
    Debug      = true,
    UseLicense = true,
    Hours      = 24,
    UseSQL     = true,

    ESX = {
        prefix = "esx",
        sharedObject = {
            event  = "esx:getSharedObject",
            export = {
                use = true,
                get = function()
                    return exports["es_extended"]:getSharedObject()
                end
            }
        }
    },

    Notify = {
        event = "esx:showNotification",
        helpEvent = "esx:showHelpNotification",
        useHelpOnJoin = true,
    },

    Discord = {
        enabled    = true,
        username   = "web-services.io",
        title      = "MC - FRAKSPERRE",
        color      = 3447003,
        avatar_url = "https://tobias.isfucking.pro/4zzE5A.png",
        icon_url   = "https://tobias.isfucking.pro/4zzE5A.png",
        webhook    = "https://ptb.discord.com/api/webhooks/1523957632703008889/FMqJJl9G2dmOIoKtPPG0sMPcIR4mX802bc1ShrB4bsyzzjkjcI1OhqiTRSYk7c15H01H",
    },

    Events = {
        setjob       = "esx:setJob",
        playerLoaded = "esx:playerLoaded",
    },

    Jobs = {
        unemployed = "unemployed",
        grade      = 0,
        whitelist  = {}
    },

    Commands = {
        setblock     = "setfraksperre",
        removeblock  = "removefraksperre",
        getblocktime = "getfraksperre",
    },

    Admins = {
        Owner                    = true,
        projektleitung           = true,
        stv_projektleitung       = true,
        management               = true,
        teamleitung              = true,
        stv_teamleitung          = true,
        developer                = true,
        fraktionsmanagement      = true,
        stv_fraktionsmanagement  = true,
        communitymanagement      = true,
        eventmanagement          = true,
        headadmin                = true,
    },

    Language = {
        blockset             = "Du hast ab nun eine Fraktions Sperre von %s Stunden",
        blockexpired         = "Deine Fraktions Sperre ist Abgelaufen du kannst nun wieder Berufe Annehmen",
        blockedjob           = "Du hast eine Aktive Fraktions Sperre du kannst derzeit keinen Beruf Annehmen",
        blocknotactive       = "Du hast keine Aktive Fraktions Sperre",
        targetnotfound       = "Es Wurde kein Spieler mit dieser ID Gefunden",
        targetnotblocked     = "Dieser Spieler Hat keine Aktive Fraktions Sperre",
        targetblocktimeleft  = "Die Fraktions Sperre von %s ist noch bis zum %s Aktiv",
        targetidmissing      = "Du hast keine ID Angegeben",
        targethasblock       = "Dieser Spieler Hat Bereits eine Fraktions Sperre",
        teamler              = "Ein Teamler hat deine Fraktionssperre aufgehoben",
        noperms              = "Du hast keine berechtigung diesen command zu nutzen",
        blocktimeleft        = "Deine Fraktions Sperre ist noch bis zum %s Aktiv",
        invalidhours         = "Bitte gib eine gültige Anzahl an Stunden an (Zahl > 0)",
        setsuccess           = "Du hast die Fraktions Sperre von %s erfolgreich für %s Stunden gesetzt",
        removesuccess        = "Du hast die Fraktions Sperre von %s erfolgreich entfernt",
    }
}

