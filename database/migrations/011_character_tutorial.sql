USE `lsrp`;

CREATE TABLE IF NOT EXISTS `character_tutorial` (
  `character_id` INT UNSIGNED NOT NULL,
  `stage` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `id_serial` VARCHAR(24) NOT NULL DEFAULT '',
  `bank_account` VARCHAR(24) NOT NULL DEFAULT '',
  `starter_granted` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`character_id`),
  UNIQUE KEY `uq_tutorial_id_serial` (`id_serial`),
  UNIQUE KEY `uq_tutorial_bank_account` (`bank_account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
