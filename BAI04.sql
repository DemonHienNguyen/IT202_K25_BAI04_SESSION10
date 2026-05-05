USE `session10`;

CREATE TABLE `Pharmacy_Inventory`(
	`Inventory_ID` INT PRIMARY KEY AUTO_INCREMENT,
    `Drug_Name` VARCHAR(255),
    `Batch_Number` VARCHAR(50),
    `Expiry_Date` DATE,
    `Quantity` INT
);

DELIMITER //

CREATE PROCEDURE SeedPharmacy()
BEGIN
    DECLARE i INT DEFAULT 1;

    WHILE i <= 100000 DO
        INSERT INTO Pharmacy_Inventory (Drug_Name, Batch_Number, Expiry_Date, Quantity)
        VALUES (
            CONCAT(
                ELT(FLOOR(1 + RAND()*5), 
                    'Paracetamol', 
                    'Aspirin', 
                    'Amoxicillin', 
                    'Vitamin C', 
                    'Ibuprofen'
                ),
                ' ',
                FLOOR(RAND()*500)
            ),
            CONCAT('BATCH', LPAD(i,6,'0')),
            DATE_ADD(CURDATE(), INTERVAL FLOOR(RAND()*365) DAY),
            FLOOR(RAND()*1000)
        );

        SET i = i + 1;
    END WHILE;
END //

DELIMITER ;

CALL SeedPharmacy();


EXPLAIN ANALYZE
SELECT * FROM `pharmacy_inventory`
WHERE `Drug_Name` = 'Paracetamol 10'
AND `Expiry_Date` ='2026-12-31';

CREATE INDEX `idx_drug` ON `Pharmacy_Inventory`(`Drug_Name`);
CREATE INDEX `idx_expiry` ON `Pharmacy_Inventory`(`Expiry_Date`);

-- '-> Filter: ((pharmacy_inventory.Expiry_Date = DATE\'2026-12-31\') and (pharmacy_inventory.Drug_Name = \'Paracetamol 10\'))  (cost=8.47 rows=1) (actual time=0.691..1.09 rows=1 loops=1)\n    
-- -> Intersect rows sorted by row ID  (cost=8.47 rows=1) (actual time=0.683..1.08 rows=1 loops=1)\n        
-- -> Index range scan on pharmacy_inventory using idx_drug over (Drug_Name = \'Paracetamol 10\')  (cost=7.12 rows=50) (actual time=0.558..0.621 rows=50 loops=1)\n        
-- -> Index range scan on pharmacy_inventory using idx_expiry over (Expiry_Date = \'2026-12-31\')  (cost=1.24 rows=251) (actual time=0.0659..0.385 rows=247 loops=1)\n'

-- có thể chỉ dùng 1 index
-- hoặc merge index (kém hơn)

DROP INDEX `idx_drug` ON `pharmacy_inventory`;
DROP INDEX `idx_expiry` ON `pharmacy_inventory`;

CREATE INDEX `idx_drug_expiry` 
ON `Pharmacy_Inventory`(`Drug_Name`, `Expiry_Date`);

DROP INDEX `idx_drug_expiry` ON `pharmacy_inventory`;

-- '-> Index lookup on pharmacy_inventory using idx_drug_expiry (Drug_Name=\'Paracetamol 10\', Expiry_Date=DATE\'2026-12-31\')  
-- (cost=0.35 rows=1) (actual time=0.0746..0.0801 rows=1 loops=1)\n'

-- Khi có composite index:
-- dùng idx_drug_expiry
-- scan cực ít dòng

EXPLAIN ANALYZE
SELECT *
FROM `Pharmacy_Inventory`
WHERE `Drug_Name` LIKE '%Para%';

-- '-> Filter: (pharmacy_inventory.Drug_Name like \'%Para%\')  
-- (cost=9310 rows=10245) (actual time=0.11..133 rows=19990 loops=1)\n    
-- -> Table scan on Pharmacy_Inventory  (cost=9310 rows=92213) (actual time=0.1..90 rows=100000 loops=1)\n'

-- MySQL không biết bắt đầu tìm từ đâu

-- Cách 1: LIKE có prefix (index hoạt động)
EXPLAIN ANALYZE
SELECT *
FROM `Pharmacy_Inventory`
WHERE `Drug_Name` LIKE 'Para%';

-- Cách 2: FULLTEXT SEARCH (xịn hơn, nhưng setup thêm)
ALTER TABLE `Pharmacy_Inventory` 
ADD FULLTEXT(`Drug_Name`);

SELECT *
FROM `Pharmacy_Inventory`
WHERE MATCH(`Drug_Name`) AGAINST('Para');
-- tìm kiếm gần giống Google
-- không bị bóp cổ như %keyword%