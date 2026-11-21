CREATE TABLE IF NOT EXISTS `companies` (
    `company_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL,
    `company_type` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `owner_character_id` INT UNSIGNED NOT NULL,
    `bank_balance` INT NOT NULL DEFAULT 0,
    `warehouse_capacity` INT UNSIGNED NOT NULL DEFAULT 100,
    `vehicle_limit` INT UNSIGNED NOT NULL DEFAULT 3,
    `member_limit` INT UNSIGNED NOT NULL DEFAULT 5,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`company_id`),
    UNIQUE KEY `uq_company_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_members` (
    `company_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `title` VARCHAR(32) NOT NULL DEFAULT 'Nhan vien',
    `joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`company_id`, `character_id`),
    UNIQUE KEY `uq_company_character` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_branches` (
    `branch_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `name` VARCHAR(64) NOT NULL,
    `branch_type` VARCHAR(24) NOT NULL DEFAULT '24/7',
    `exterior_x` FLOAT NOT NULL, `exterior_y` FLOAT NOT NULL,
    `exterior_z` FLOAT NOT NULL, `exterior_a` FLOAT NOT NULL,
    `interior_id` INT NOT NULL DEFAULT 6,
    `virtual_world` INT NOT NULL DEFAULT 0,
    `status` TINYINT NOT NULL DEFAULT 1,
    `cash_balance` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`branch_id`),
    KEY `idx_branch_company` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL, `vehicle_id` INT UNSIGNED NOT NULL,
    `note` VARCHAR(64) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`), KEY `idx_company_vehicle` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_warehouse` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `item_name` VARCHAR(64) NOT NULL, `amount` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`), KEY `idx_warehouse_company` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_contracts` (
    `contract_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL, `title` VARCHAR(96) NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'Moi', `reward` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`contract_id`), KEY `idx_contract_company` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_logs` (
    `log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL, `actor_character_id` INT UNSIGNED NOT NULL,
    `action` VARCHAR(32) NOT NULL, `details` VARCHAR(255) NOT NULL DEFAULT '',
    `amount` INT NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`log_id`), KEY `idx_company_logs` (`company_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `company_branches`
(`branch_id`,`company_id`,`name`,`branch_type`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`,`interior_id`,`virtual_world`)
VALUES (1,0,'Unity 24/7 - Taxi HQ','24/7',1833.4200,-1842.7200,13.5781,180.0,6,31001);
