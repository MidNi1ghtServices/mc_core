Config = Config or {}


---------------------------------------------------------------
-- MODUL: NotifyConfig
---------------------------------------------------------------

NotifyConfig = {
    system = "esx",             -- "auto" | "hex_hud" | "ox_lib" | "esx" | "qbcore" | "custom"
    customEvent = nil,           -- z.B. "mc_core:notify", nur bei system = "custom"
    customHelpEvent = nil,       -- eigenes Event für Help-Texte, optional
    defaultDuration = 5000
}

---------------------------------------------------------------
-- MODUL: Abschleppsystem
---------------------------------------------------------------
Config.Framework = "esx"             -- ESX oder QBCore (auch von Mechanic genutzt, gleicher Wert)
Config.Debug = false                  -- (auch von Mechanic genutzt, gleicher Wert)

Config.DaysUntilTow = 3
Config.CheckIntervalMinutes = 10

Config.TowDepot = vector3(409.12, -1623.55, 29.29)
Config.TowMessage = "Dein Fahrzeug (%s) wurde abgeschleppt, da es %s Tage nicht bewegt wurde."

Config.Zones = {
    { name = "207",     coords = vector3(-403.37, 1204.96, 325.93), radius = 40.0 },
    { name = "garage2", coords = vector3(-334.12, -135.55, 39.01),  radius = 25.0 }
}

Config.DeleteVehicleOnTow = true
Config.NotifyPlayerOnTow = true

Config.MySQLTable = "vehicle_tracking"
Config.ChatPrefix = "^1[Abschleppsystem] ^7"

Config.EnableNPCTowtruck = false
Config.EnableTowFees = false
Config.TowFeeAmount = 500
Config.EnableTowNUI = false

---------------------------------------------------------------
-- MODUL: AntiAFK
---------------------------------------------------------------
Config.AFKWebhook = "https://discordapp.com/api/webhooks/1532384533775777862/ThzMQljMGZ2eJeqlNmErFe6anwxEcZ1jMzk_vdvKYVhchqfd1tuKuuolrEf-_sunsG4c" -- TODO: eigenen Webhook eintragen
Config.AntiAFK = {
    Enabled = true,              -- System an/aus
    KickAfterMinutes = 5,       -- Nach wie vielen Minuten Inaktivität gekickt wird
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
        UseAcePermission = true,       -- z.B. add_ace group.admin mc_core.afkbypass allow
        AcePermission = "mc_core.afkbypass",
        Identifiers = {                -- Alternativ/zusätzlich: feste Liste an Identifiern (license, steam, discord, etc.)
            -- "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        },
        Jobs = {                       -- Jobs, die nie gekickt werden (z.B. Support/Staff-Job)
            -- "admin",
        }
    }
}

---------------------------------------------------------------
-- MODUL: Discord Logging (AFK-Kicks + txAdmin-Kicks)
---------------------------------------------------------------
Config.DiscordLogging = {
    Enabled = true,
    LogAFKKicks = true,       -- eigene AFK-Kicks in Discord loggen
    LogTxAdminKicks = true,   -- Kicks über txAdmin (z.B. per Admin-Menü) in Discord loggen
}


---------------------------------------------------------------
-- MODUL: Crafter
---------------------------------------------------------------
Config.UseOxTarget = false -- (auch von Labor genutzt, gleicher Wert)

Config.CraftZones = {
        {
            name = "orange", label = "Crafter orange",
            coords = vector3(435.8295, 6505.3667, 28.6095), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "orangensaft", label = "Orange", craftingTime = 10,
                  reward = { item = "orangensaft", amount = 2 }, ingredients = { orange = 10 } }
            }
        },
        {
            name = "apfel", label = "Crafter apfel",
            coords = vector3(117.52, -329.98, 45.39), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "apfel", label = "Apfel", craftingTime = 10,
                  reward = { item = "apfelsaft", amount = 2 }, ingredients = { apfel = 10 } }
            }
        },
        {
            name = "Trauben", label = "Crafter Trauben",
            coords = vector3(1215.7689, 1846.4213, 78.9088), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "trauben", label = "Trauben", craftingTime = 10,
                  reward = { item = "traubensaft", amount = 2 }, ingredients = { trauben = 10 } }
            }
        },
        {
            name = "Kirsche", label = "Crafter Kirsche",
            coords = vector3(926.8948, -1560.3735, 30.7403), radius = 2.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "kirsche", label = "Kirsche", craftingTime = 10,
                  reward = { item = "kirschesaft", amount = 2 }, ingredients = { Kirsche = 10 } }
            }
        },
        {
            name = "Banane", label = "Crafter Banane",
            coords = vector3(821.9493, -3194.3872, 5.9008), radius = 5.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5, 5, 0.4),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "bananen", label = "Banane", craftingTime = 10,
                  reward = { item = "bananensaft", amount = 2 }, ingredients = { bananen = 10 } }
            }
        },
        {
            name = "birne", label = "Crafter Birne",
            coords = vector3(232.0012, -3312.1704, 5.7903), radius = 5.0,
            blip = { enabled = true, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(1.5, 1.5, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "birne", label = "Birne", craftingTime = 10,
                  reward = { item = "birnesaft", amount = 2 }, ingredients = { birne = 10 } }
            }
        },
        {
            name = "WaffenCraft", label = "Crafter Birne",
            coords = vector3(898.51, -3222.67, -98.3), radius = 5.0,
            blip = { enabled = false, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5.0, 5.0, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "birne", label = "Birne", craftingTime = 10,
                  reward = { item = "birnesaft", amount = 2 }, ingredients = { birne = 10 } }
            }
        },
        {
            name = "waffenrahmen", label = "Crafter waffenrahmen",
            coords = vector3(754.13, -1841.54, 29.29), radius = 5.0,
            blip = { enabled = false, sprite = 365, color = 46, scale = 0.8 },
            marker = { enabled = true, type = 1, size = vec3(5.0, 5.0, 0.5),
                       color = { r = 255, g = 255, b = 0, a = 150 }, z_offset = -1.0 },
            crafts = {
                { name = "waffenrahmen", label = "waffenrahmen", craftingTime = 10,
                  reward = { item = "waffenrahmen", amount = 3 }, ingredients = { metal_erz = 30 } }
            }
        }
    }

---------------------------------------------------------------
-- MODUL: Discord Rich Presence
---------------------------------------------------------------
Config.DiscordAppId = "1530555515988611234"

Config.DiscordLogo = "logo"             -- Großes Bild (Asset-Name aus dem Discord Dev Portal)
Config.DiscordLogoText = "MC Roleplay"

Config.DiscordSmallLogo = "small"       -- Kleines Bild (Asset-Name aus dem Discord Dev Portal)
Config.DiscordSmallLogoText = "FiveM"

Config.DiscordStatusFormat = "👥 %s Spieler | ID: %s" -- %s = Spieleranzahl, %s = eigene Server-ID

Config.DiscordButton1Label = "🌐 Discord"
Config.DiscordButton1Url = "https://discord.gg/4DZ7D36BxP"

Config.DiscordButton2Label = "🎮 Server beitreten"
Config.DiscordButton2Url = "fivem://connect/DEINE-IP:30120" -- Hier deine echte Server-IP/Domain eintragen

Config.DiscordUpdateInterval = 60000 -- ms, wie oft die Rich Presence aktualisiert wird

---------------------------------------------------------------
-- MODUL: Elevator  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
ElevatorConfig = {
    Key = 38, -- E

    Marker = {
        size = vec3(0.25, 0.25, 0.25),
        color = { r = 0, g = 120, b = 255, a = 180 },
        drawDist = 10.0,
        interactDist = 1.4
    },

    Elevators = {
        {
            name = "Krankenhaus Fahrstuhl",
            pos = vec3(298.47, -584.76, 43.26),
            floors = {
                { label = "EG",        coords = vec3(298.47, -584.76, 43.26) },
                { label = "1. Stock",  coords = vec3(298.47, -584.76, 48.26) },
                { label = "Dach",      coords = vec3(298.47, -584.76, 54.26) }
            }
        }
    }
}

---------------------------------------------------------------
-- MODUL: Event
---------------------------------------------------------------
Config.Event = {
    Timeout = 8000, -- 8 Sekunden
    Ace = "event.use", -- ACE Permission
}

---------------------------------------------------------------
-- MODUL: Farming
---------------------------------------------------------------
Config.FarmingBonus = {
    enabled = true,      -- Bonus aktiv?
    multiplier = 2,      -- 2 = doppelt sammeln
    startHour = 16,      -- Startzeit (16 Uhr)
    endHour = 19          -- Endzeit (19 Uhr)
}

Config.Farming = {

        ["Kirsche"] = {
            coords = vector3(5035.4941, -4700.4673, 7.5553),
            output = "Kirsche", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Kirsche zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 1, scale = 1.0, shortrange = true, name = "kirschefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["bananen"] = {
            coords = vector3(5062.43, -4818.24, 16.81),
            output = "bananen", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um bananen zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 5, scale = 1.0, shortrange = true, name = "bananenfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["birne"] = {
            coords = vector3(5513.9424, -5338.4414, 20.1274),
            output = "birne", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um birne zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 25, scale = 1.0, shortrange = true, name = "Birnefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["trauben"] = {
            coords = vector3(-1713.2019, 2330.2693, 63.9261),
            output = "trauben", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Trauben zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 83, scale = 1.0, shortrange = true, name = "Traubenfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["orange"] = {
            coords = vector3(2419.0820, 4673.5991, 33.9015),
            output = "orange", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Orange zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 47, scale = 1.0, shortrange = true, name = "Orangefarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        ["apfel"] = {
            coords = vector3(233.9311, 6512.4971, 31.2423),
            output = "apfel", outputanzahl = 1,
            random = { enabled = true, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um Apfel zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = false, chance = 10,
                items = {
                    { type = "item", name = "water", label = "Wasser", amount = 1 },
                    { type = "weapon", name = "weapon_knife", label = "Messer" }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = {},
            blip = { id = 238, color = 69, scale = 1.0, shortrange = true, name = "Apfelfarm", enabled = true },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        },

        -- Waffenfarm
        ["waffen"] = {
            coords = vector3(-554.8976, 5324.3403, 73.5995),
            output = "waffen", outputanzahl = 5,
            random = { enabled = false, min = 4, max = 10 },
            helpmsg = "~INPUT_CONTEXT~ um metal zu sammeln",
            time = 5, zonesize = 10.0, needed = {},
            random_items = {
                enabled = true, chance = 40,
                items = {
                    { type = "item", name = "steel", label = "Steel", amount = 5 },
                    { type = "item", name = "rubber", label = "Rubber", amount = 5 },
                    { type = "item", name = "metalscrap", label = "Metal Scrap", amount = 5 }
                }
            },
            animation = { animDictionary = "pickup_object", animationName = "pickup_low" },
            fixed_job = false, disallowed_jobs = { "police" },
            blip = { id = 238, color = 69, scale = 1.0, shortrange = true, name = "waffenfarm", enabled = false },
            marker = { typ = 1, move = true, rotate = true, z_offset = 1.0,
                       color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 15.0, y = 15.0, z = 1.0 } }
        }
    }

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

---------------------------------------------------------------
-- MODUL: GiveCar  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
ConfigGiveCar = {
    AdminGroups = {
        ["Owner"] = true,
        ["superadmin"] = true
    },

    SpawnVehicleOnGive = false,

    AutoPlate = {
        enabled = true,
        prefix = "",
        length = 5
    },

    Logging = {
        enabled = false,
        webhook = ""
    },

    Messages = {
        noPerms = "~r~Du hast keine Berechtigung.",
        usage = "~y~Benutzung: /givecar [ID] [model] [plate(optional)]",
        playerNotFound = "~r~Spieler nicht gefunden.",
        carGivenAdmin = "~g~Fahrzeug vergeben: ~w~%model% (%plate%) → ID %id%",
        carGivenPlayer = "~g~Du hast ein neues Fahrzeug erhalten: ~w~%model% (%plate%)"
    }
}

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

---------------------------------------------------------------
-- MODUL: Labor
-- (Config.UseOxTarget wurde bereits im Crafter-Modul oben gesetzt,
--  beide Original-Dateien nutzten denselben Wert "false")
---------------------------------------------------------------
Config.Labors = {
    {
        id = 1,
        label = "Kokain Labor",
        coords = vector3(107.76, -326.56, 45.68),
        radius = 2.0,
        blip = { enabled = false, sprite = 499, color = 1, scale = 0.8 },
        marker = { r = 0, g = 255, b = 100, alpha = 150 },
        inputItem = "chemicals",
        processTime = 60000,
        moneyPerItem = 150
    }
}

---------------------------------------------------------------
-- MODUL: Maut  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
-- Server kann darüber jede Notify anzeigen lassen, läuft durch MC_Notify (Auto-Detect)
RegisterNetEvent("mc_core:notifyClient")
AddEventHandler("mc_core:notifyClient", function(title, msg, ntype, duration)
    MC_Notify(title, msg, ntype, duration)
end)

MautConfig = {
    Price = 500,
    SpeedFactor = 6.0,
    HighSpeedBase = 10000,
    UseBank = true,

    FreeJobs = {
        police = false,
        fib = true,
        ambulance = true,
    },

    Cooldown = 1, -- 2 Minuten – verhindert, dass an derselben Mautstelle sofort erneut abgebucht wird

    Tolls = {
        { coords = vector3(-2698.93, 2358.39, 16.83), radius = 20.0, name = "Great Ocean Highway Maut" },   
        { coords = vector3(-1328.21, 2459.62, 25.75), radius = 10.0, name = "route 68 3 Maut" },  
        { coords = vector3(-473.39, 2821.08, 36.83), radius = 10.0, name = "route 68 2 Maut" },
        { coords = vector3(-435.04, 2819.35, 38.75), radius = 10.0, name = "route 68 1 Maut" },
        { coords = vector3(225.5, 2487.45, 54.98), radius = 10.0, name = "Senora Road Sand weg Maut" },
        { coords = vector3(340.13, 2538.65, 44.42), radius = 10.0, name = "Senora Road Maut" },
        { coords = vector3(1962.2, 2624.93, 45.98), radius = 10.0, name = "Senora Freeway SG Maut" },
        { coords = vector3(2012.8, 2580.3, 54.6), radius = 10.0, name = "Senora Freeway Maut" },
        { coords = vector3(2056.4, 2537.33, 57.31), radius = 10.0, name = "Senora Freeway zug  Maut" },
        { coords = vector3(2157.87, 2447.29, 89.08), radius = 10.0, name = "Senora Way sand weg Maut" },
        { coords = vector3(2542.02, 2104.3, 19.62), radius = 10.0, name = "Senora Way Maut" }
    },

    Webhook = "https://ptb.discord.com/api/webhooks/1528903129339400376/-C6BQVA6OEXc3DYFLKJ333kPW0zDq0o5Jc4s0CbU31hFa25aP9Q9zLjfD5BR01ZJoDVF"
}

---------------------------------------------------------------
-- MODUL: Mechanic
-- (Config.Framework und Config.Debug wurden bereits oben im
--  Abschleppsystem-Modul gesetzt, beide Original-Dateien nutzten
--  dieselben Werte "esx" / false)
---------------------------------------------------------------
Config.Locale = 'de' -- auch von Sperrzone genutzt, gleicher Wert
Config.SalaryFallback = 500

Config.Key = 38
Config.Align = 'center-left'

Config.RequestMechanic = "requestmechanic"
Config.JobName = 'mechanic'
Config.SpawnRadius = 50
Config.MaxTiming = 150
Config.CommandDelay = 15
Config.MechanicModel = "s_m_y_dockwork_01"
Config.MechanicVehicle = "utillitruck3"

-- Hinweis: im Original gab es zwei Definitionen von Config.Message;
-- die zweite (untere) hat die erste überschrieben. Hier daher nur
-- die tatsächlich wirksame Version übernommen.
Config.Message = function(message)
    Framework.ShowNotification(message)
end

Config.GetMoneyMethod = false

Config.EnableDraw = true
Config.DrawColor = { r = 255, g = 0, b = 0, a = 255 }
Config.DrawSize = 0.3
Config.DrawX = 0.4
Config.DrawY = 0.005

Config.MechanicInsurance = true
Config.PayIntervall = 15
Config.MechanicInsuranceNPC = "s_m_y_construct_01"
Config.MechanicInsuranceLocation = vector4(495.7212, -1340.4844, 29.3132, 352.1842)
Config.FillInsuranceText = 32

Config.EnableBlip = true
Config.BlipName = "Car insurance"
Config.BlipCoords = vector3(495.7212, -1340.4844, 29.3132)
-- KONFLIKT: config_sperrzone.lua nutzte ebenfalls "Config.BlipSprite"
-- (Wert 305, für Sperrzonen-Blips). Der Mechanic-Wert (225) bleibt
-- hier unter dem Originalnamen; der Sperrzone-Wert liegt weiter unten
-- unter dem neuen Namen "Config.SperrzoneBlipSprite" (305).
-- -> sperrezone.lua muss entsprechend angepasst werden!
Config.BlipSprite = 225
Config.BlipSize = 1.0
Config.BlipColour = 43

Config.JobGradesData = "job_grades"

Config.MechanicInsuranceBasic = "fixed"
Config.MechanicInsuranceBasicCost = 100
Config.RequiredMechanicBasic = 0
Config.MechanicDurationBasic = 60
Config.RepairDurationBasic = 45

Config.MechanicInsuranceDefault = "fixed"
Config.MechanicInsuranceDefaultCost = 250
Config.RequiredMechanicDefault = 1
Config.MechanicDurationDefault = 120
Config.RepairDurationDefault = 30

Config.MechanicInsurancePremium = "fixed"
Config.MechanicInsurancePremiumCost = 500
Config.RequiredMechanicPremium = 2
Config.MechanicDurationPremium = 60
Config.RepairDurationPremium = 15

Config.MechanicCost = 1000
Config.RequiredMechanic = 1
Config.MechanicDuration = 120
Config.RepairDuration = 60

---------------------------------------------------------------
-- MODUL: Moneywash
---------------------------------------------------------------
Config.Moneywash = {
    useOxTarget = true,

    blackMoneyAccount = "black_money",
    cleanMoneyType    = "cash",

    maxActiveJobs = 3,

    minFee = 5,
    maxFee = 50,

    locations = {
        {
            id     = 1,
            label  = "Waschsalon - Innenstadt",
            coords = vector3(1135.01, -789.12, 57.6),
            radius = 2.0,
           -- blip   = { enabled = true, sprite = 617, color = 5, scale = 0.8 },
            marker = { r = 9, g = 164, b = 241, alpha = 140 },
        }
    },

    packages = {
        { id = 1, amount = 1000000, fee = 40, time = 10 },
        { id = 2, amount = 500000,  fee = 20, time = 54 },
        { id = 3, amount = 100000,  fee = 35, time = 54 },
    },

    custom = {
        enabled   = true,
        minAmount = 1000,
        maxAmount = 2000000,

        baseTimeMinutes   = 10,
        minutesPerMillion = 40,
        maxTimeMinutes    = 180,

        feeTiers = {
            { upto = 50000,    fee = 5  },
            { upto = 150000,   fee = 12 },
            { upto = 400000,   fee = 20 },
            { upto = 800000,   fee = 30 },
            { upto = 1500000,  fee = 40 },
            { upto = 2000000,  fee = 50 },
        },
    },

    policeNotify = {
        enabled  = true,
        chance   = 60,
        cooldown = 10,
        blipTime = 3,
        jobs     = { "police" },
        blipSprite = 161,
        blipColor  = 1,
        blipLabel  = "Verdächtige Aktivität",
    },
}

---------------------------------------------------------------
-- MODUL: Namecheck  (eigenständige globale Tabelle, wie im Original)
---------------------------------------------------------------
config_namecheck = {
    identifier = {
        type = "license",
        prefix = false
    },

    debug = false,
    console_prints = true,

    multichar = {
        enabled = true,
        table = "users",
        identifier_column = "identifier",
        db_prefix_pattern = "char%%:%s"
    },

    naming = {
        standard = "{job} | {firstname} {lastname}",
        team = {
            enabled = true,
            template = "[MC] | {firstname} {lastname}",
            useBypassGroups = true
        }
    },

    job = {
        use_job_label = true,
        job_shorts = {
            ["police"] = "LSPD",
            ["ambulance"] = "EMS",
            ["unemployed"] = "ZIVI"
        }
    },

    bypass = {
        groups = {
    
        },
        identifiers = {
            "d349c528cff8aacc207987d36fe491c1b9a7bbb3",
            "29be6b803481db0126ed1e26a8eeee5fc6aaa748"

        },
        team_groups = {
            "Owner", 
            "stv_Owner", 
            "projektleitung", 
            "stv_projektleitung",
            "management", 
            "teamleitung", 
            "stv_teamleitung", 
            "developer",
            "fraktionsmanagement", 
            "stv_fraktionsmanagement",
            "communitymanagement", 
            "eventmanagement", 
            "headadmin",
            "superadmin", 
            "admin", 
            "supportleitung", 
            "headmoderator",
            "moderator", 
            "headsupporter", 
            "supporter", 
            "guide"
        }
    },

    ui = {
        colors = {
            theme = "#1092e3",
            warning = "#ffc107",
            error = "#1092e3"
        },
        reject_icon_url = "https://tobias.isfucking.pro/pSyfSm.png",
        language = "de",
        translations = {
            ["de"] = {
                ["title"] = "Verbindung abgelehnt",
                ["access_denied"] = "Zugriff verweigert",
                ["reason_label"] = "Grund:",
                ["checking_name"] = "Dein Name wird überprüft...",
                ["name_correct"] = "Dein Name ist korrekt!",
                ["name_incorrect"] = "Dein Name entspricht nicht dem vorgegebenen Schema - Dein Name muss lauten:",
                ["identifier_not_found"] = "Identifier nicht gefunden!",
                ["template_empty"] = "Template ist leer!",
                ["template_no_job"] = "Template beinhaltet nicht den job!",
                ["job_not_found"] = "Job nicht gefunden -> Konfigurationsfehler\nBitte melde dich bei einem Admin!",
                ["no_chars_found"] = "Keine Charaktere gefunden! Bitte erstelle zuerst einen Charakter."
            },
            ["en"] = {
                ["title"] = "Connection rejected",
                ["access_denied"] = "Access denied",
                ["reason_label"] = "Reason:",
                ["checking_name"] = "Your name is being checked...",
                ["name_correct"] = "Your name is correct!",
                ["name_incorrect"] = "Your name does not match the given schema - Your name must be:",
                ["identifier_not_found"] = "Identifier not found!",
                ["template_empty"] = "Template is empty!",
                ["template_no_job"] = "Template does not include the job!",
                ["job_not_found"] = "Job not found -> Configuration error\nPlease contact an admin!",
                ["no_chars_found"] = "No characters found! Please create a character first."
            }
        }
    }
}

---------------------------------------------------------------
-- MODUL: NpcBlocker  (eigenständige globale Werte, wie im Original)
---------------------------------------------------------------
ZoneCenter = vector3(-326.8, 1327.61, 341.18)
ZoneRadius = 230.0
DebugNPCBlocker = false

---------------------------------------------------------------
-- MODUL: Purge
---------------------------------------------------------------
Config.Purge = {
    Duration = 15 * 60, -- Sekunden

    Webhook = "",

    GiveWeapons = true,
    Weapons = {
        "weapon_knife",
        "weapon_bat",
        "weapon_pistol"
    },

    ScreenEffect = true
}

---------------------------------------------------------------
-- MODUL: Revive
---------------------------------------------------------------
Config.Revive = {

    Price = 2500,
    UseBank = true,
    Countdown = 300, -- 5 Minuten

    Blips = {
        enabled = true,
        name = "Revive Station",
        sprite = 153,     -- Medic Herz
        color = 1,        -- Rot
        scale = 0.9
    },

    Marker = {
        enabled = true,
        type = 2,          -- 1 = vertical, 2 = horizontal circle
        size = vector3(0.5, 0.5, 0.5),
        color = { r = 255, g = 0, b = 0, a = 180 }, -- Rot WS-Style
        rotate = false
    },

    Stations = {
        { coords = vector3(300.26, -578.82, 44.26), heading = 72.1 },
        { coords = vector3(1839.0, 3672.0, 34.28), heading = 210.0 }
    },

    -- DISCORD WEBHOOK
    Discord = {
        enabled = true,
        servername = "web.services.io",
        url = "https://web-services.io/",
        icon = "https://tobias.isfucking.pro/4zzE5A.png",
        color = "3447003",
        username = "MC - REVIVESTATION",
        webhook = "https://ptb.discord.com/api/webhooks/1525546367718789140/-TkF6elMoScwB3CytKoXP12fa8ZiPcMZLv4bChb4-6CQwHM9aSGH_RdAuyUSmt32YBEp"
    }

}

---------------------------------------------------------------
-- MODUL: Sperrzone
-- (Config.Locale wurde bereits im Mechanic-Modul gesetzt, beide
--  Original-Dateien nutzten denselben Wert 'de')
---------------------------------------------------------------
Config.DefaultRadius = 50.0
Config.MinRadius = 10.0
Config.MaxRadius = 5000.0
Config.DrawDistance = 600.0
Config.MarkerType = 1
Config.MarkerZOffset = 0.0

Config.Commands = {
    create      = 'sperrzone',
    remove      = 'sperrzone_del',
    adminList   = 'sperrzone_list',
    adminClear  = 'sperrzone_clear',
}

Config.AdminGroups = {
    ['Owner'] = true,
    ['superadmin'] = true,
}

Config.Jobs = {
    ['police'] = {
        label = 'LSPD', blipColor = 3,
        markerColor = { r = 30, g = 100, b = 255, a = 100 },
    },
    ['sheriff'] = {
        label = 'Sheriff', blipColor = 47,
        markerColor = { r = 200, g = 170, b = 60, a = 100 },
    },
    ['fib'] = {
        label = 'FIB', blipColor = 4,
        markerColor = { r = 20, g = 20, b = 90, a = 100 },
    },
    ['ambulance'] = {
        label = 'Fire / EMS', blipColor = 1,
        markerColor = { r = 255, g = 40, b = 40, a = 100 },
    },
    ['army'] = {
        label = 'Army', blipColor = 2,
        markerColor = { r = 40, g = 160, b = 40, a = 100 },
    },
    ['admin'] = {
        label = 'Midnight City', blipColor = 2,
        markerColor = { r = 40, g = 160, b = 40, a = 100 },
    },
}

-- KONFLIKT (siehe Hinweis oben im Mechanic-Modul): Original-Wert war
-- "Config.BlipSprite = 305". Da "Config.BlipSprite" bereits vom
-- Mechanic-Modul (225) belegt ist, liegt der Sperrzonen-Wert hier
-- unter "Config.SperrzoneBlipSprite". BITTE sperrezone.lua anpassen!
Config.SperrzoneBlipSprite = 305
Config.BlipScale = 1.0
Config.ShowRadiusBlip = true
Config.RadiusBlipAlpha = 150

Config.Notify = function(msg, type)
    ESX.ShowNotification(msg)
end

Config.Discord = {
    webhook = '',
    botName = 'Sperrzone Logs',
    colorCreate = 3066993,
    colorRemove = 15158332,
    colorClear  = 15105570,
}

Config.Locales = {
    de = {
        no_permission     = 'Du bist nicht berechtigt, Sperrzonen zu erstellen.',
        zone_created      = 'Sperrzone erstellt (Radius: %s m).',
        zone_removed      = 'Sperrzone entfernt.',
        not_in_own_zone   = 'Du musst dich in einer selbst erstellten Zone befinden, um sie zu entfernen.',
        invalid_radius    = 'Ungültiger Radius. Muss zwischen %s und %s Metern liegen.',
        all_cleared       = 'Alle Sperrzonen wurden gelöscht.',
        no_admin          = 'Du hast keine Berechtigung dafür.',
        zone_list_header  = 'Aktive Sperrzonen: %s',
        blip_name         = '%s Sperrzone',
    }
}

-- Hilfsfunktion für Sperrzone-Übersetzungen (Original-Verhalten, jetzt
-- wieder auf das flache Config.Locale / Config.Locales bezogen)
function _L(key, ...)
    local str = Config.Locales[Config.Locale][key]
    if not str then return key end
    if ... then return string.format(str, ...) end
    return str
end

---------------------------------------------------------------
-- MODUL: Verkauf
---------------------------------------------------------------
Config.Verkauf = {

    ["orangensaft"] = {
        coords = vector3(-1504.9540, 1511.6925, 115.2885),
        input = { item = "orangensaft", label = "Orangensaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 80, max = 115 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Orangen zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 47, scale = 1.0, shortrange = true, name = "Orangen Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["apfelsaft"] = {
        coords = vector3(-46.2101, 1945.8883, 190.1862),
        input = { item = "apfelsaft", label = "Apfelsaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 70, max = 105 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Apfel zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 69, scale = 1.0, shortrange = true, name = "Apfel Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["traubensaft"] = {
        coords = vector3(1477.1738, 2722.0024, 37.6274),
        input = { item = "traubensaft", label = "Traubensaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 90, max = 135 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Trauben zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 83, scale = 1.0, shortrange = true, name = "Trauben Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["kirschesaft"] = {
        coords = vector3(446.0303, 84.0746, 98.9259),
        input = { item = "Kirschesaft", label = "Kirschesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 105, max = 160 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Kirsche zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 1, scale = 1.0, shortrange = true, name = "Kirsche Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["bananensaft"] = {
        coords = vector3(-1005.3513, -308.9769, 37.8649),
        input = { item = "bananensaft", label = "Bananesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 80, max = 120 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Bananen zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 5, scale = 1.0, shortrange = true, name = "Bananen Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    },

    ["birnesaft"] = {
        coords = vector3(-1037.6805, -1397.1294, 5.5532),
        input = { item = "birnesaft", label = "Birnesaft", anzahl = 1 },
        outputprice = 500,
        generatePrice = { enabled = true, min = 75, max = 110 },
        blackmoney = false,
        helpmsg = "~INPUT_CONTEXT~ um Birne zu verkaufen",
        time = 5, zonesize = 10.0,
        animation = { animDictionary = "mp_common", animationName = "givetake1_a" },
        disallowed_jobs = { "police", "unemployed" },
        blip = { id = 500, color = 25, scale = 1.0, shortrange = true, name = "Birne Verkauf", enabled = true },
        marker = { typ = 1, move = true, rotate = true, z_offset = 1.5,
                   color = { r = 255, g = 0, b = 0, t = 140 }, size = { x = 10.0, y = 10.0, z = 2.0 } }
    }
}