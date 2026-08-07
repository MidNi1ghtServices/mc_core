Config = Config or {}

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

