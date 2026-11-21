-- LS:RP Inventory persistence
-- Character inventory rows + weapon instance metadata + LEFT/RIGHT assignment.

CREATE TABLE IF NOT EXISTS `player_inventory` (
    `inventory_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT NOT NULL,
    `slot_index` TINYINT UNSIGNED NOT NULL,
    `item_id` SMALLINT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL DEFAULT 1,

    `weapon_serial` INT UNSIGNED NULL DEFAULT NULL,
    `weapon_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `ammo_type` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `loaded_ammo` INT UNSIGNED NOT NULL DEFAULT 0,
    `weapon_condition` TINYINT UNSIGNED NOT NULL DEFAULT 0,

    -- 0 = not equipped, 1 = LEFT HAND, 2 = RIGHT HAND.
    `equipped_hand` TINYINT UNSIGNED NOT NULL DEFAULT 0,

    PRIMARY KEY (`inventory_id`),
    UNIQUE KEY `uq_character_inventory_slot` (`character_id`, `slot_index`),
    UNIQUE KEY `uq_inventory_weapon_serial` (`weapon_serial`),
    KEY `idx_inventory_character` (`character_id`),
    CONSTRAINT `fk_inventory_character`
        FOREIGN KEY (`character_id`) REFERENCES `player_characters` (`character_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
