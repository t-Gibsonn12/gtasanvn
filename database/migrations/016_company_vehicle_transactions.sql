CREATE TABLE IF NOT EXISTS `company_vehicle_transactions` (
    `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED NOT NULL,
    `buyer_character_id` INT UNSIGNED NOT NULL,
    `model_id` SMALLINT UNSIGNED NOT NULL,
    `gross_amount` INT NOT NULL,
    `tax_amount` INT NOT NULL,
    `net_amount` INT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction_id`),
    KEY `idx_vehicle_tx_branch` (`branch_id`, `created_at`),
    KEY `idx_vehicle_tx_company` (`company_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
