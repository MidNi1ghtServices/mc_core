Config = Config or {}

---------------------------------------------------------------
-- MODUL: sv_updater
---------------------------------------------------------------
-- Einfacher Versions-Check beim Ressourcenstart: vergleicht die lokal
-- installierte Version (fxmanifest.lua -> version) mit der Version im
-- GitHub-Repository. Lädt/ersetzt nichts automatisch, informiert nur
-- über die Server-Konsole.
Config.updateCheck = true
