---------------------------------------------------------------
-- MODUL: Allgemein (Framework/Debug)
---------------------------------------------------------------
Config = Config or {}

Config.Framework = "esx"             -- ESX oder QBCore (auch von Mechanic genutzt, gleicher Wert)
Config.Debug = false                  -- (auch von Mechanic genutzt, gleicher Wert)

---------------------------------------------------------------
-- Sonstige globale Flags (gehören zu keinem der 3 gesplitteten Module)
---------------------------------------------------------------
Config.WeaponAnims = true
Config.InfiniteStamina = true
Config.BodyShot = false
Config.MaxKMH = 100

---------------------------------------------------------------
-- NoNPC
---------------------------------------------------------------
Config.EnableNPC = true        -- Hauptschalter: bei "false" wird alles deaktiviert (Info: Nach erneutem Aktivieren des Hauptschalters muss der Server neugestartet werden.)

Config.EnableWalkNPC = true    -- Laufende NPCs aktivieren
Config.DensityPed = 0.2        -- Spawn-Rate (0.1 - 1.0)

Config.EnableDriveCars = true  -- Fahrende NPC-Fahrzeuge aktivieren
Config.EnableParkedCars = false -- Geparkte Fahrzeuge spawnen lassen

Config.DensityTraffic = 0.1    -- Spawn-Rate (0.1 - 1.0)

Config.EnableCops = false      -- Polizei-NPCs aktivieren
Config.EnableAmbulance = false -- Rettungsdienst-NPCs aktivieren

Config.EnableBoats = true      -- Boote mit NPC aktivieren

---------------------------------------------------------------
-- Basic Logs
---------------------------------------------------------------
Config.DateFormat = '%d/%m/%Y [%X]' -- Format des Datums

Config.ShowIPAddress = false -- IP-Adresse des Spielers anzeigen

Config.EnableConnectLog = false -- Connect-Log aktivieren
Config.ConnectionWebhook = "" -- Webhook

Config.EnableDisconnectLog = false -- Disconnect-Log aktivieren
Config.DisconnectWebhook = "" -- Webhook

Config.EnableNullFix = true -- Der NullFix ersetzt den Namen des Fahrzeugs etc. im Menü durch den hier eingetragenen Namen.
Config.NullFix = {
    modelCarName = "rightCar"
}

---------------------------------------------------------------
-- Extra Settings
---------------------------------------------------------------
Config.AllowSeatCommand = true -- Sollen Spieler den Sitzplatz wechseln können?
Config.SeatCommand = "seat" -- Befehl zum Sitzplatzwechsel

Config.AllowHitWithWeapons = true -- Spieler können mit Waffen zuschlagen

---------------------------------------------------------------
-- Vehicle Settings
---------------------------------------------------------------
Config.EnableVehicleReward = false -- Standard: false (VehicleReward gibt Waffen beim Einsteigen in Polizeifahrzeuge etc.)
Config.AllowKickDriver = false -- Standard: false (aktiviert das Rauswerfen des Fahrers)
Config.EnableSlipStream = false -- Slipstream aktivieren/deaktivieren
