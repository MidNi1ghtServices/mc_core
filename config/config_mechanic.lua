Config = Config or {}

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

