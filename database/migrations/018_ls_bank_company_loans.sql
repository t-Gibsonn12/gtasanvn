-- San Andreas Bank - Los Santos government branch and Company credit system.

ALTER TABLE `companies`
    ADD COLUMN IF NOT EXISTS `government_owned` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `admin_managed` TINYINT UNSIGNED NOT NULL DEFAULT 0;

INSERT INTO `companies`
    (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`government_owned`,`admin_managed`)
VALUES
    (900002,'San Andreas Bank - Los Santos',4,0,20000000,100,20,1,1)
ON DUPLICATE KEY UPDATE
    `name`=VALUES(`name`),
    `company_type`=4,
    `government_owned`=1,
    `admin_managed`=1;

CREATE TABLE IF NOT EXISTS `ls_bank_state` (
    `state_id` TINYINT UNSIGNED NOT NULL,
    `regulatory_capital` BIGINT NOT NULL DEFAULT 20000000,
    `tax_revenue` BIGINT NOT NULL DEFAULT 0,
    `interest_revenue` BIGINT NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`state_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ls_bank_state` (`state_id`,`regulatory_capital`)
VALUES (1,20000000);

CREATE TABLE IF NOT EXISTS `company_loans` (
    `loan_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `lender_company_id` INT UNSIGNED NOT NULL,
    `borrower_company_id` INT UNSIGNED NOT NULL,
    `principal` BIGINT UNSIGNED NOT NULL,
    `outstanding_principal` BIGINT UNSIGNED NOT NULL,
    `daily_interest_bp` INT UNSIGNED NOT NULL DEFAULT 100,
    `term_days` TINYINT UNSIGNED NOT NULL DEFAULT 12,
    `director_signature` VARCHAR(32) NOT NULL DEFAULT '',
    `bank_signature` VARCHAR(32) NOT NULL DEFAULT 'Cuozg',
    `current_day` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `status` ENUM('ACTIVE','MATURED','PAID','DEFAULTED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `next_due_at` DATETIME NULL,
    `maturity_at` DATETIME NOT NULL,
    `closed_at` DATETIME NULL,
    PRIMARY KEY (`loan_id`),
    KEY (`borrower_company_id`,`status`),
    KEY (`next_due_at`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `company_loan_bills` (
    `bill_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `loan_id` BIGINT UNSIGNED NOT NULL,
    `company_id` INT UNSIGNED NOT NULL,
    `bill_type` ENUM('INTEREST','FINAL') NOT NULL,
    `due_day` TINYINT UNSIGNED NOT NULL,
    `amount` BIGINT UNSIGNED NOT NULL,
    `status` ENUM('UNPAID','PAID','OVERDUE') NOT NULL DEFAULT 'UNPAID',
    `due_at` DATETIME NOT NULL,
    `paid_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`bill_id`),
    UNIQUE KEY (`loan_id`,`bill_type`,`due_day`),
    KEY (`company_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ls_bank_transactions` (
    `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `source` VARCHAR(40) NOT NULL,
    `actor_character_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `amount` BIGINT NOT NULL,
    `details` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction_id`),
    KEY (`source`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
