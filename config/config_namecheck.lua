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
            --"d349c528cff8aacc207987d36fe491c1b9a7bbb3",
            --"29be6b803481db0126ed1e26a8eeee5fc6aaa748"

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

