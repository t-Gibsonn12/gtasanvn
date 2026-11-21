-- LS:RP migration 009
-- Persistent audit trail for ATM, bank and dealership transactions.

USE `lsrp`;

CREATE TABLE IF NOT EXISTS `economy_transactions` (
  `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` INT UNSIGNED NOT NULL,
  `target_character_id` INT UNSIGNED NULL DEFAULT NULL,
  `transaction_type` VARCHAR(32) NOT NULL,
  `amount` INT NOT NULL,
  `cash_balance` INT NOT NULL DEFAULT 0,
  `bank_balance` INT NOT NULL DEFAULT 0,
  `details` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`transaction_id`),
  KEY `idx_economy_character_created` (`character_id`, `created_at`),
  KEY `idx_economy_target_created` (`target_character_id`, `created_at`),
  CONSTRAINT `fk_economy_character`
    FOREIGN KEY (`character_id`) REFERENCES `player_characters` (`character_id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_economy_target_character`
    FOREIGN KEY (`target_character_id`) REFERENCES `player_characters` (`character_id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
