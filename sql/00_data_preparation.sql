/*
============================================================
Project: Supply Chain Network Optimization
Script: 00_data_preparation.sql

Purpose:
Standardize imported CSV tables:
- rename columns to snake_case
- remove empty columns
- convert numeric text values
- prepare tables for analytical scripts

Run this script after importing raw CSV files into PostgreSQL.
============================================================
*/


/* ==========================================================
1. ORDERLIST
========================================================== */

ALTER TABLE orderlist RENAME COLUMN "Order ID" TO order_id;
ALTER TABLE orderlist RENAME COLUMN "Order Date" TO order_date;
ALTER TABLE orderlist RENAME COLUMN "Origin Port" TO origin_port;
ALTER TABLE orderlist RENAME COLUMN "Service Level" TO service_level;
ALTER TABLE orderlist RENAME COLUMN "Ship ahead day count" TO ship_ahead_day_count;
ALTER TABLE orderlist RENAME COLUMN "Ship Late Day count" TO ship_late_day_count;
ALTER TABLE orderlist RENAME COLUMN "Product ID" TO product_id;
ALTER TABLE orderlist RENAME COLUMN "Plant Code" TO plant_code;
ALTER TABLE orderlist RENAME COLUMN "Destination Port" TO destination_port;
ALTER TABLE orderlist RENAME COLUMN "Unit quantity" TO unit_quantity;

ALTER TABLE orderlist RENAME COLUMN "Carrier" TO carrier;
ALTER TABLE orderlist RENAME COLUMN "Customer" TO customer;
ALTER TABLE orderlist RENAME COLUMN "TPT" TO tpt;
ALTER TABLE orderlist RENAME COLUMN "Weight" TO weight;

ALTER TABLE orderlist
ALTER COLUMN order_id TYPE bigint USING order_id::bigint,
ALTER COLUMN order_date TYPE date USING order_date::date,
ALTER COLUMN product_id TYPE bigint USING product_id::bigint,
ALTER COLUMN unit_quantity TYPE numeric USING unit_quantity::numeric,
ALTER COLUMN weight TYPE numeric USING REPLACE(weight::text, ',', '.')::numeric,
ALTER COLUMN tpt TYPE integer USING tpt::integer,
ALTER COLUMN ship_ahead_day_count TYPE integer USING ship_ahead_day_count::integer,
ALTER COLUMN ship_late_day_count TYPE integer USING ship_late_day_count::integer;


/* ==========================================================
2. FREIGHTRATES
========================================================== */
select * from freightrates f  

ALTER TABLE freightrates RENAME COLUMN "Carrier" TO carrier;
ALTER TABLE freightrates RENAME COLUMN "Carrier type" TO carrier_type;
ALTER TABLE freightrates RENAME COLUMN "minimum cost" TO min_cost;
ALTER TABLE freightrates RENAME COLUMN "orig_port_cd" TO orig_port_code; 
ALTER TABLE freightrates RENAME COLUMN "dest_port_cd" TO dest_port_code;
ALTER TABLE freightrates RENAME COLUMN "minm_wgh_qty" TO min_weight_qty;
ALTER TABLE freightrates RENAME COLUMN "max_wgh_qty" TO max_weight_qty;
ALTER TABLE freightrates RENAME COLUMN "svc_cd" TO svc_code;
ALTER TABLE freightrates RENAME COLUMN "rate - stawka jednostkowa: weight x rate" TO rate;

-- Clean text fields
UPDATE freightrates
SET
    carrier = TRIM(carrier),
    orig_port_code = TRIM(orig_port_code),
    dest_port_code = TRIM(dest_port_code),
    svc_code = TRIM(svc_code),
    mode_dsc = TRIM(mode_dsc),
    carrier_type = TRIM(carrier_type);

-- Convert numeric fields.

ALTER TABLE freightrates
ALTER COLUMN min_cost TYPE numeric USING min_cost::numeric,
ALTER COLUMN rate TYPE numeric USING rate::numeric;

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'freightrates'
ORDER BY ordinal_position;

/* ==========================================================
3. PLANTPORTS
========================================================== */

ALTER TABLE plantports RENAME COLUMN "Plant Code" TO plant_code;
ALTER TABLE plantports RENAME COLUMN "Port" TO port;

ALTER TABLE plantports DROP COLUMN IF EXISTS "Column3";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column4";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column5";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column6";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column7";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column8";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column9";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column10";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column11";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column12";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column13";
ALTER TABLE plantports DROP COLUMN IF EXISTS "Column14";

UPDATE plantports
SET
    plant_code = TRIM(plant_code),
    port = TRIM(port);


/* ==========================================================
4. PRODUCTSPERPLANT
========================================================== */

ALTER TABLE productsperplant RENAME COLUMN "Plant Code" TO plant_code;
ALTER TABLE productsperplant RENAME COLUMN "Product ID" TO product_id;

ALTER TABLE productsperplant
ALTER COLUMN product_id TYPE bigint USING product_id::bigint;

UPDATE productsperplant
SET plant_code = TRIM(plant_code);




/* ==========================================================
5. VMICUSTOMERS
========================================================== */

ALTER TABLE vmicustomers RENAME COLUMN "Plant Code" TO plant_code;
ALTER TABLE vmicustomers RENAME COLUMN "Customers" TO customer;

UPDATE vmicustomers
SET
    plant_code = TRIM(plant_code),
    customer = TRIM(customer);


/* ==========================================================
6. WHCAPACITIES
========================================================== */

ALTER TABLE whcapacities RENAME COLUMN "Plant ID" TO plant_code;
ALTER TABLE whcapacities RENAME COLUMN "Daily Capacity " TO daily_capacity;

ALTER TABLE whcapacities
ALTER COLUMN daily_capacity TYPE integer USING daily_capacity::integer;

UPDATE whcapacities
SET plant_code = TRIM(plant_code);


/* ==========================================================
7. WHCOSTS
========================================================== */

ALTER TABLE whcosts RENAME COLUMN "WH" TO plant_code;
ALTER TABLE whcosts RENAME COLUMN "Cost/unit" TO cost_per_unit;

-- Remove empty imported row, if present
DELETE FROM whcosts
WHERE plant_code IS NULL
   OR TRIM(plant_code::text) = '';

UPDATE whcosts
SET plant_code = TRIM(plant_code);

ALTER TABLE whcosts
ALTER COLUMN cost_per_unit TYPE numeric USING REPLACE(cost_per_unit::text, ',', '.')::numeric;


/* ==========================================================
8. BASIC TECHNICAL VALIDATION
========================================================== */

SELECT 'orderlist' AS table_name, COUNT(*) AS row_count FROM orderlist
UNION ALL
SELECT 'freightrates', COUNT(*) FROM freightrates
UNION ALL
SELECT 'plantports', COUNT(*) FROM plantports
UNION ALL
SELECT 'productsperplant', COUNT(*) FROM productsperplant
UNION ALL
SELECT 'vmicustomers', COUNT(*) FROM vmicustomers
UNION ALL
SELECT 'whcapacities', COUNT(*) FROM whcapacities
UNION ALL
SELECT 'whcosts', COUNT(*) FROM whcosts;