-- Persistent hunger and thirst values for each character.
USE `lsrp`;

CREATE TABLE IF NOT EXISTS `character_needs` (
  `character_id` INT UNSIGNED NOT NULL,
  `hunger` TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `thirst` TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  CONSTRAINT `fk_character_needs_character` FOREIGN KEY (`character_id`)
    REFERENCES `player_characters` (`character_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
