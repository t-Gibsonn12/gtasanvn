ALTER TABLE `companies`
    ADD COLUMN IF NOT EXISTS `parent_company_id` INT UNSIGNED NOT NULL DEFAULT 0;

INSERT INTO `companies`
    (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`parent_company_id`,`government_owned`,`admin_managed`)
VALUES
    (900003,'Westbridge Realty Group',5,0,5000000,50,10,0,0,1),
    (900004,'Sterling Heights Properties',5,0,5000000,50,10,0,0,1),
    (900005,'Pacific Crown Properties',5,0,10000000,80,20,900002,0,1),
    (900006,'Redwood Commercial Holdings',5,0,5000000,50,10,0,0,1),
    (900007,'Kingsley Urban Estates',5,0,5000000,50,10,0,0,1),
    (900008,'Arcadia Residential Group',5,0,5000000,50,10,0,0,1)
ON DUPLICATE KEY UPDATE
    `name`=VALUES(`name`),
    `company_type`=5,
    `parent_company_id`=VALUES(`parent_company_id`),
    `admin_managed`=1;

CREATE TABLE IF NOT EXISTS `real_estate_buildings`
(
    `building_id` TINYINT UNSIGNED NOT NULL,
    `owner_company_id` INT UNSIGNED NOT NULL,
    `building_name` VARCHAR(64) NOT NULL,
    `total_floors` TINYINT UNSIGNED NOT NULL,
    `rooms_per_floor` TINYINT UNSIGNED NOT NULL DEFAULT 8,
    `exterior_x` FLOAT NOT NULL,
    `exterior_y` FLOAT NOT NULL,
    `exterior_z` FLOAT NOT NULL,
    `exterior_a` FLOAT NOT NULL,
    `building_type` ENUM('OFFICE','APARTMENT') NOT NULL DEFAULT 'OFFICE',
    PRIMARY KEY (`building_id`),
    KEY (`owner_company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `real_estate_units`
    ADD COLUMN IF NOT EXISTS `building_id` TINYINT UNSIGNED NOT NULL DEFAULT 3 AFTER `unit_id`,
    ADD COLUMN IF NOT EXISTS `owner_company_id` INT UNSIGNED NOT NULL DEFAULT 900005 AFTER `building_id`;

DROP INDEX IF EXISTS `floor_number` ON `real_estate_units`;
CREATE UNIQUE INDEX IF NOT EXISTS `uq_building_unit`
    ON `real_estate_units` (`building_id`,`floor_number`,`unit_number`);

INSERT INTO `real_estate_buildings`
    (`building_id`,`owner_company_id`,`building_name`,`total_floors`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`)
VALUES
    (1,900003,'Westbridge Realty Group',15,1734.9081,-1265.5187,13.5420,292.8434),
    (2,900004,'Sterling Heights Properties',15,1684.4510,-1340.1721,17.4409,267.3335),
    (3,900005,'Pacific Crown Properties',20,1569.6294,-1334.7303,16.4844,147.8718),
    (4,900006,'Redwood Commercial Holdings',16,1564.6221,-1274.6573,17.4063,355.8702),
    (5,900007,'Kingsley Urban Estates',18,1495.1992,-1280.7034,14.5814,199.0367)
ON DUPLICATE KEY UPDATE
    `owner_company_id`=VALUES(`owner_company_id`),
    `building_name`=VALUES(`building_name`),
    `total_floors`=VALUES(`total_floors`),
    `exterior_x`=VALUES(`exterior_x`),
    `exterior_y`=VALUES(`exterior_y`),
    `exterior_z`=VALUES(`exterior_z`),
    `exterior_a`=VALUES(`exterior_a`);

INSERT INTO `real_estate_buildings`
    (`building_id`,`owner_company_id`,`building_name`,`total_floors`,`rooms_per_floor`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`,`building_type`)
VALUES
    (6,900008,'Arcadia Residential Group',1,0,1499.9048,-1379.6538,14.0254,119.3944,'APARTMENT')
ON DUPLICATE KEY UPDATE
    `owner_company_id`=900008,
    `building_name`='Arcadia Residential Group',
    `exterior_x`=1499.9048,
    `exterior_y`=-1379.6538,
    `exterior_z`=14.0254,
    `exterior_a`=119.3944,
    `building_type`='APARTMENT';

-- Unit rows for every office floor are generated idempotently by the
-- gamemode at startup. The highest floor of each building is reserved as
-- the headquarters of its real-estate Company.
