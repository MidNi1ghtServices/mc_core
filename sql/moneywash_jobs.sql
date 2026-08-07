CREATE TABLE IF NOT EXISTS `mc_moneywash_jobs` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `identifier`   VARCHAR(60) NOT NULL,
    `amount`       INT NOT NULL,
    `fee`          INT NOT NULL,
    `clean_amount` INT NOT NULL,
    `started_at`   BIGINT NOT NULL,
    `finish_at`    BIGINT NOT NULL,

    INDEX `idx_identifier` (`identifier`)
);
