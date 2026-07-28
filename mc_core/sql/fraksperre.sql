-- MC Core - Fraktionssperre
-- Manuell importieren (phpMyAdmin/HeidiSQL) ODER einfach starten lassen:
-- server/Fraktionssperre.lua erstellt diese Tabelle beim Resource-Start automatisch (CREATE TABLE IF NOT EXISTS).
-- Diese Datei liegt nur zusätzlich im sql-Ordner, falls ihr eure DB-Struktur zentral versioniert.

CREATE TABLE IF NOT EXISTS `fraksperre` (
  `identifier` VARCHAR(60) NOT NULL,
  `until` INT(11) NOT NULL,
  `hours` INT(11) NOT NULL,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
