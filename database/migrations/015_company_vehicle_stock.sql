CREATE TABLE IF NOT EXISTS `company_vehicle_stock` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED NOT NULL,
    `model_id` SMALLINT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `sale_price` INT UNSIGNED NOT NULL,
    `wholesale_price` INT UNSIGNED NOT NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_branch_model` (`branch_id`, `model_id`),
    KEY `idx_vehicle_stock_company` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
