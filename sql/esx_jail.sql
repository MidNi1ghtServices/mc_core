CREATE TABLE IF NOT EXISTS `jail_inmates` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(60) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `jail_id` INT NOT NULL,
  `time` INT NOT NULL DEFAULT 0 COMMENT 'Reststrafe in Minuten',
  `officer` VARCHAR(100),
  `reason` VARCHAR(255),
  `jailed_at` DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Eigenständiges Admin-Jail-System (/adminjail, /putinjail): kein Bezug zu
-- Config.Jails, dafür Rückkehr-Koordinaten für den Teleport nach der Entlassung.
CREATE TABLE IF NOT EXISTS `admin_jail` (
  `identifier` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100),
  `jail_time` INT NOT NULL,
  `jail_reason` VARCHAR(255),
  `in_jail` TINYINT(1) DEFAULT 0,
  `return_x` FLOAT DEFAULT NULL,
  `return_y` FLOAT DEFAULT NULL,
  `return_z` FLOAT DEFAULT NULL,
  `return_h` FLOAT DEFAULT NULL,
  PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `jail_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(60),
  `name` VARCHAR(100),
  `action` VARCHAR(50) COMMENT 'jailed / released / bribed_success / bribed_fail / escaped / time_updated',
  `details` VARCHAR(255),
  `jail_id` INT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `jail_storage` (
  `identifier` VARCHAR(60) PRIMARY KEY,
  `skin` LONGTEXT,
  `loadout` LONGTEXT,
  `inventory` LONGTEXT,
  `jail_id` INT
);
