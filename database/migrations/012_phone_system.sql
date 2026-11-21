CREATE TABLE IF NOT EXISTS `character_phone_profiles` (
    `character_id` INT UNSIGNED NOT NULL,
    `phone_number` INT UNSIGNED NOT NULL,
    `powered` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `silent` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `battery` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    PRIMARY KEY (`character_id`),
    UNIQUE KEY `uq_phone_profile_number` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `phone_contact_entries` (
    `contact_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `contact_name` VARCHAR(32) NOT NULL,
    `phone_number` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`contact_id`),
    UNIQUE KEY `uq_phone_contact_owner_number` (`character_id`,`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `phone_communication_logs` (
    `log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `phone_number` INT UNSIGNED NOT NULL,
    `target_number` INT UNSIGNED NOT NULL,
    `event_type` VARCHAR(24) NOT NULL,
    `content` VARCHAR(160) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`log_id`),
    KEY `idx_phone_log_character` (`character_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
