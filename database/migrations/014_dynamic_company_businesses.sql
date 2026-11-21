-- Retire the fixed Taxi HQ prototype. Every new door is placed by its owner.
DELETE FROM `company_branches`
WHERE `name` = 'Unity 24/7 - Taxi HQ'
  AND `exterior_x` BETWEEN 1833.3 AND 1833.5
  AND `exterior_y` BETWEEN -1842.8 AND -1842.6;

ALTER TABLE `company_branches`
    ADD COLUMN IF NOT EXISTS `branch_type_id`
    TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `company_id`;

ALTER TABLE `company_warehouse`
    ADD COLUMN IF NOT EXISTS `branch_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `company_id`,
    ADD COLUMN IF NOT EXISTS `item_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `branch_id`,
    ADD COLUMN IF NOT EXISTS `unit_price` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `amount`;

CREATE UNIQUE INDEX IF NOT EXISTS `uq_branch_item`
ON `company_warehouse` (`branch_id`, `item_id`);

CREATE TABLE IF NOT EXISTS `server_treasury` (
    `treasury_id` TINYINT UNSIGNED NOT NULL,
    `tax_balance` BIGINT NOT NULL DEFAULT 0,
    `lifetime_tax` BIGINT NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`treasury_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `server_treasury` (`treasury_id`) VALUES (1);

CREATE TABLE IF NOT EXISTS `server_tax_transactions` (
    `tax_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `source` VARCHAR(32) NOT NULL,
    `gross_amount` INT NOT NULL,
    `tax_amount` INT NOT NULL,
    `details` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`tax_id`),
    KEY `idx_tax_company_created` (`company_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
