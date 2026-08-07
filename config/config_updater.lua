Config = Config or {}

---------------------------------------------------------------
-- MODUL: sv_updater
---------------------------------------------------------------
-- Einfacher Versions-Check beim Ressourcenstart: vergleicht die lokal
-- installierte Version (fxmanifest.lua -> version) mit der Version im
-- GitHub-Repository. Lädt/ersetzt nichts automatisch, informiert nur
-- über die Server-Konsole.
Config.updateCheck = true

-- Nur nötig, wenn das GitHub-Repository PRIVAT ist. raw.githubusercontent.com
-- liefert bei privaten Repos ohne Auth-Token immer einen 404 zurück (auch wenn
-- der Pfad korrekt ist) - mit einem Personal Access Token (Fine-grained,
-- Berechtigung "Contents: Read-only" reicht) funktioniert der Abruf trotzdem.
-- Leer lassen ('') wenn das Repo public ist.
Config.updateCheckToken = ''
