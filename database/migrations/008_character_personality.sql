-- LS:RP migration 008
-- Character personality for the creator profile.

USE `lsrp`;

ALTER TABLE `player_characters`
    ADD COLUMN IF NOT EXISTS `personality` VARCHAR(127) NOT NULL DEFAULT '' AFTER `birth_place`;
