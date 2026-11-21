ALTER TABLE `companies`
    ADD COLUMN IF NOT EXISTS `parent_company_id` INT UNSIGNED NOT NULL DEFAULT 0;

INSERT INTO `companies`
    (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`parent_company_id`,`government_owned`,`admin_managed`)
VALUES
    (900003,'Pacific Crown Properties',5,0,5000000,50,10,900002,1,1)
ON DUPLICATE KEY UPDATE
    `name`=VALUES(`name`),`parent_company_id`=900002;

CREATE TABLE IF NOT EXISTS `real_estate_units`
(
    `unit_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `floor_number` TINYINT UNSIGNED NOT NULL,
    `unit_number` TINYINT UNSIGNED NOT NULL,
    `status` ENUM('VACANT','LEASED','OWNED') NOT NULL DEFAULT 'VACANT',
    `occupant_company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `monthly_price` INT UNSIGNED NOT NULL DEFAULT 250000,
    `lease_started_at` DATETIME NULL,
    `lease_expires_at` DATETIME NULL,
    PRIMARY KEY (`unit_id`),
    UNIQUE KEY (`floor_number`,`unit_number`),
    KEY (`occupant_company_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `real_estate_transactions`
(
    `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `contract_code` VARCHAR(48) NOT NULL,
    `unit_id` INT UNSIGNED NOT NULL,
    `buyer_company_id` INT UNSIGNED NOT NULL,
    `seller_company_id` INT UNSIGNED NOT NULL,
    `transaction_type` ENUM('LEASE','PURCHASE','RENEWAL') NOT NULL,
    `gross_amount` INT UNSIGNED NOT NULL,
    `tax_amount` INT UNSIGNED NOT NULL,
    `net_amount` INT UNSIGNED NOT NULL,
    `actor_character_id` INT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction_id`),
    KEY (`buyer_company_id`,`created_at`),
    KEY (`seller_company_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `real_estate_custom_offices`
(
    `office_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `exterior_x` FLOAT NOT NULL,
    `exterior_y` FLOAT NOT NULL,
    `exterior_z` FLOAT NOT NULL,
    `exterior_a` FLOAT NOT NULL,
    PRIMARY KEY (`office_id`),
    UNIQUE KEY (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
