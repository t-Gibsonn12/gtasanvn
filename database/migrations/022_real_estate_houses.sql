CREATE TABLE IF NOT EXISTS `real_estate_houses` (
    `house_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `manager_company_id` INT UNSIGNED NOT NULL,
    `owner_character_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `size` TINYINT UNSIGNED NOT NULL,
    `interior_id` TINYINT UNSIGNED NOT NULL,
    `construction_cost` INT UNSIGNED NOT NULL,
    `sale_price` INT UNSIGNED NOT NULL,
    `status` ENUM('FOR_SALE','OWNED') NOT NULL DEFAULT 'FOR_SALE',
    `exterior_x` FLOAT NOT NULL,
    `exterior_y` FLOAT NOT NULL,
    `exterior_z` FLOAT NOT NULL,
    `exterior_a` FLOAT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `sold_at` DATETIME NULL,
    PRIMARY KEY (`house_id`),
    KEY (`manager_company_id`,`status`),
    KEY (`owner_character_id`),
    KEY (`salesperson_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `real_estate_house_transactions` (
    `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `house_id` INT UNSIGNED NOT NULL,
    `buyer_character_id` INT UNSIGNED NOT NULL,
    `seller_company_id` INT UNSIGNED NOT NULL,
    `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `gross_amount` INT UNSIGNED NOT NULL,
    `tax_amount` INT UNSIGNED NOT NULL,
    `commission_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `net_amount` INT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction_id`),
    KEY (`house_id`,`created_at`),
    KEY (`seller_company_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
