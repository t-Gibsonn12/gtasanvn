ALTER TABLE `real_estate_houses`
    ADD COLUMN IF NOT EXISTS `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0
    AFTER `owner_character_id`;

ALTER TABLE `real_estate_house_transactions`
    ADD COLUMN IF NOT EXISTS `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0
    AFTER `seller_company_id`,
    ADD COLUMN IF NOT EXISTS `commission_amount` INT UNSIGNED NOT NULL DEFAULT 0
    AFTER `tax_amount`;

CREATE INDEX IF NOT EXISTS `idx_house_salesperson`
    ON `real_estate_houses` (`salesperson_character_id`);
