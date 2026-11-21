ALTER TABLE `companies`
    ADD COLUMN IF NOT EXISTS `tax_code` VARCHAR(32) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS `website` VARCHAR(80) NOT NULL DEFAULT '';

UPDATE `companies`
SET
    `tax_code` = CASE
        WHEN `tax_code`='' THEN CONCAT('LS-',LPAD(`company_id`,6,'0'))
        ELSE `tax_code`
    END,
    `website` = CASE
        WHEN `website`='' THEN CONCAT('www.company-',`company_id`,'.ls')
        ELSE `website`
    END;

-- Office contracts are legally displayed as 99-year leases but function as
-- permanent ownership and therefore do not expire in gameplay.
UPDATE `real_estate_units`
SET
    `status`='OWNED',
    `lease_expires_at`=NULL
WHERE `status`='LEASED';
