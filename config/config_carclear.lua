---------------------------------------------------------------
-- MODUL: CarClear
---------------------------------------------------------------
Config = Config or {}

Config.EnableCarClear = false              -- CarClear an/aus

Config.CarClearTime = 15                  -- Minuten bis Fahrzeuge gelöscht werden
Config.CarClearDistance = 100             -- Mindestabstand (Meter) zu Spielern, damit ein Fahrzeug gecleart wird

Config.CarClearNotificationOn = { 5, 3, 1 } -- Bei diesen verbleibenden Minuten wird nochmal erinnert
Config.CarClearNotification = "Alle Fahrzeuge die %s Meter von Spielern entfernt sind, werden in %s Minuten gelöscht"
Config.CarClearClearedNotification = "Die Fahrzeug wurden gecleart"

-- Fortschrittsbalken-Anzeige (an das genutzte HUD anpassen)
function Config.ProgressBar(time, text)
    TriggerEvent("nightlife_hud:progressBar", time, text)
end

-- Server-weite Ankündigung (z.B. über txAdmin)
function Config.CarClearAnnounce(message)
    print("CarClearAnnounce", message)
    TriggerEvent("txAdmin:events:announcement", {
        author = "System",
        message = message
    })
end
