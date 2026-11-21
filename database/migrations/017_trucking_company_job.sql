ALTER TABLE `player_vehicles`
    ADD COLUMN IF NOT EXISTS `company_vehicle` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `company_note` VARCHAR(32) NOT NULL DEFAULT '';

INSERT INTO `companies`
    (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`)
VALUES
    (900001,'Los Santos Logistics',3,0,0,500,500)
ON DUPLICATE KEY UPDATE
    `name`=VALUES(`name`),
    `company_type`=VALUES(`company_type`),
    `member_limit`=VALUES(`member_limit`),
    `vehicle_limit`=VALUES(`vehicle_limit`);

ALTER TABLE `companies`
    ADD COLUMN IF NOT EXISTS `government_owned` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `admin_managed` TINYINT UNSIGNED NOT NULL DEFAULT 0;

UPDATE `companies`
SET `government_owned`=1, `admin_managed`=1, `company_type`=3
WHERE `company_id`=900001;

CREATE TABLE IF NOT EXISTS `trucking_contracts` (
    `contract_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `contract_type` ENUM('AUTO','BUSINESS') NOT NULL,
    `created_by` VARCHAR(48) NOT NULL,
    `source_company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `destination_branch_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `cargo_kind` VARCHAR(16) NOT NULL,
    `item_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `model_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `cargo_amount` INT UNSIGNED NOT NULL,
    `sale_price` INT UNSIGNED NOT NULL DEFAULT 0,
    `supplier_cost` INT UNSIGNED NOT NULL DEFAULT 0,
    `reward` INT UNSIGNED NOT NULL,
    `destination_x` FLOAT NOT NULL, `destination_y` FLOAT NOT NULL, `destination_z` FLOAT NOT NULL,
    `status` ENUM('OPEN','ASSIGNED','COMPLETED','FAILED','CANCELLED') NOT NULL DEFAULT 'OPEN',
    `driver_character_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `accepted_at` DATETIME NULL, `completed_at` DATETIME NULL,
    PRIMARY KEY (`contract_id`),
    KEY `idx_truck_status_type` (`status`,`contract_type`),
    KEY `idx_truck_destination` (`destination_branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_employee_profiles` (
    `company_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `contract_signed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `contract_ended_at` DATETIME NULL,
    `kpi_points` INT UNSIGNED NOT NULL DEFAULT 0,
    `completed_orders` INT UNSIGNED NOT NULL DEFAULT 0,
    `payroll_balance` INT NOT NULL DEFAULT 0,
    `base_salary_total` INT UNSIGNED NOT NULL DEFAULT 0,
    `bonus_total` INT UNSIGNED NOT NULL DEFAULT 0,
    `insurance_paid_total` INT UNSIGNED NOT NULL DEFAULT 0,
    `vehicle_fee_total` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_daily_settlement` DATE NULL,
    PRIMARY KEY (`company_id`,`character_id`),
    KEY `idx_company_employee_kpi` (`company_id`,`kpi_points`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_work_logs` (
    `work_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `contract_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `tax_code` VARCHAR(32) NOT NULL,
    `work_type` VARCHAR(32) NOT NULL,
    `route_from` VARCHAR(64) NOT NULL,
    `route_to` VARCHAR(64) NOT NULL,
    `base_reward` INT UNSIGNED NOT NULL,
    `labor_bonus` INT UNSIGNED NOT NULL,
    `safety_bonus` INT UNSIGNED NOT NULL,
    `punctual_bonus` INT UNSIGNED NOT NULL,
    `cargo_care_bonus` INT UNSIGNED NOT NULL,
    `route_bonus` INT UNSIGNED NOT NULL,
    `total_income` INT UNSIGNED NOT NULL,
    `company_profit` INT UNSIGNED NOT NULL,
    `kpi_earned` TINYINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`work_id`),
    KEY `idx_company_work_character` (`character_id`,`created_at`),
    KEY `idx_company_work_company` (`company_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
