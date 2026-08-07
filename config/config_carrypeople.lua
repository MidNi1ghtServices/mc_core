Config = Config or {}

---------------------------------------------------------------
-- MODUL: CarryPeople
---------------------------------------------------------------
-- ERSETZT das vorherige selbstgebaute Carry-System (Job-Check,
-- Konsens per /carryaccept, ESX-Anbindung). Auf Wunsch durch das
-- eigenständige "CarryPeople"-Script ersetzt: einfacher, kein
-- Consent-Screen, kein Job-Filter - dafür genau wie das Original.
Config.CarryPeople = {
    enabled = true,      -- an/aus
    command = 'carry',   -- Befehlsname, frei anpassbar
    maxDistance = 3.0,   -- wie nah man dran sein muss, um jemanden zu tragen
}

