/*
============================================================
Project: Supply Chain Network Optimization
Script: 01_data_model_assessment.sql

Purpose:
Validate the prepared data model before business analysis.

This script checks:
- row counts after preparation,
- table structures,
- duplicate records in key reference tables,
- basic relationship consistency between tables.

Run after:
00_data_preparation.sql
============================================================
*/


/* ==========================================================
1. ROW COUNTS AFTER DATA PREPARATION
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


/* ==========================================================
2. BASIC STRUCTURE CHECKS
========================================================== */

SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'orderlist',
      'freightrates',
      'plantports',
      'productsperplant',
      'vmicustomers',
      'whcapacities',
      'whcosts'
  )
ORDER BY table_name, ordinal_position;


/* ==========================================================
3. DUPLICATE CHECKS
========================================================== */

-- 3.1 OrderList: duplicated order_id

SELECT
    order_id,
    COUNT(*) AS records
FROM orderlist
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 3.2 ProductsPerPlant: duplicated product-plant combinations

SELECT
    plant_code,
    product_id,
    COUNT(*) AS records
FROM productsperplant
GROUP BY plant_code, product_id
HAVING COUNT(*) > 1;


-- 3.3 PlantPorts: duplicated plant-port combinations

SELECT
    plant_code,
    port,
    COUNT(*) AS records
FROM plantports
GROUP BY plant_code, port
HAVING COUNT(*) > 1;


-- 3.4 VmiCustomers: duplicated customer-plant combinations

SELECT
    plant_code,
    customer,
    COUNT(*) AS records
FROM vmicustomers
GROUP BY plant_code, customer
HAVING COUNT(*) > 1;


-- 3.5 WhCapacities: duplicated plant_code

SELECT
    plant_code,
    COUNT(*) AS records
FROM whcapacities
GROUP BY plant_code
HAVING COUNT(*) > 1;


-- 3.6 WhCosts: duplicated plant_code

SELECT
    plant_code,
    COUNT(*) AS records
FROM whcosts
GROUP BY plant_code
HAVING COUNT(*) > 1;



/* ==========================================================
4. BASIC REFERENCE CHECKS
========================================================== */

-- 4.1 Plants used in OrderList but missing in WhCapacities

SELECT DISTINCT
    o.plant_code
FROM orderlist o
LEFT JOIN whcapacities wc
    ON o.plant_code = wc.plant_code
WHERE wc.plant_code IS NULL
ORDER BY o.plant_code;


-- 4.2 Plants used in OrderList but missing in WhCosts

SELECT DISTINCT
    o.plant_code
FROM orderlist o
LEFT JOIN whcosts w
    ON o.plant_code = w.plant_code
WHERE w.plant_code IS NULL
ORDER BY o.plant_code;


-- 4.3 Plants used in ProductsPerPlant but missing in WhCapacities

SELECT DISTINCT
    p.plant_code
FROM productsperplant p
LEFT JOIN whcapacities wc
    ON p.plant_code = wc.plant_code
WHERE wc.plant_code IS NULL
ORDER BY p.plant_code;

/*
Validation result:

ProductsPerPlant contains one non-standard location: CND9.

This location is not present in:
- PlantPorts
- WhCapacities
- WhCosts

Therefore it is excluded naturally during candidate network generation
and does not affect the optimization results.
*/

-- 4.4 Plants used in ProductsPerPlant but missing in WhCosts

SELECT DISTINCT
    p.plant_code
FROM productsperplant p
LEFT JOIN whcosts w
    ON p.plant_code = w.plant_code
WHERE w.plant_code IS NULL
ORDER BY p.plant_code;


-- 4.5 Plants used in PlantPorts but missing in WhCapacities

SELECT DISTINCT
    pp.plant_code
FROM plantports pp
LEFT JOIN whcapacities wc
    ON pp.plant_code = wc.plant_code
WHERE wc.plant_code IS NULL
ORDER BY pp.plant_code;


-- 4.6 Plants used in VmiCustomers but missing in WhCapacities

SELECT DISTINCT
    v.plant_code
FROM vmicustomers v
LEFT JOIN whcapacities wc
    ON v.plant_code = wc.plant_code
WHERE wc.plant_code IS NULL
ORDER BY v.plant_code;


/* ==========================================================
5. HISTORICAL ROUTING VS CURRENT PRODUCT AVAILABILITY
========================================================== */

-- Orders where historical plant does not support the ordered product
-- according to the current ProductsPerPlant table.
-- This is not necessarily an error: OrderList is historical,
-- while ProductsPerPlant represents current network constraints.

SELECT
    COUNT(*) AS orders_without_current_product_plant_match
FROM orderlist o
LEFT JOIN productsperplant p
    ON o.plant_code = p.plant_code
    AND o.product_id = p.product_id
WHERE p.product_id IS NULL;


/* ==========================================================
6. HISTORICAL ROUTING VS FREIGHTRATES COVERAGE
========================================================== */

-- This check tests whether historical non-CRF orders can be matched
-- to current FreightRates based on:
-- origin port, destination port, service level and weight band.
-- Missing matches are expected because current constraints may differ
-- from historical routing.

SELECT
    COUNT(DISTINCT o.order_id) AS historical_non_crf_orders,
    COUNT(DISTINCT CASE WHEN fr.carrier IS NOT NULL THEN o.order_id END) AS orders_with_current_freight_rate,
    COUNT(DISTINCT CASE WHEN fr.carrier IS NULL THEN o.order_id END) AS orders_without_current_freight_rate
FROM orderlist o
LEFT JOIN freightrates fr
    ON o.origin_port = fr.orig_port_cd
    AND o.destination_port = fr.dest_port_cd
    AND o.service_level = fr.svc_cd
    AND o.weight BETWEEN fr.minm_wgh_qty AND fr.max_wgh_qty
WHERE o.carrier <> 'V44_3';


/* ==========================================================
7. DATA MODEL VALIDATION SUMMARY
========================================================== */

/*
Expected interpretation:

1. Duplicate checks should ideally return 0 rows.
2. Missing plant references should be reviewed if returned.
3. Historical Product-Plant mismatches may occur because:
   - OrderList represents historical routing,
   - ProductsPerPlant represents current product availability.
4. Historical FreightRate mismatches may occur because:
   - V44_3/CRF is excluded,
   - FreightRates represents current available courier options,
   - current constraints may not fully reproduce historical routing.

This script validates technical consistency.
Business interpretation is continued in:
02_data_understanding_and_constraint_analysis.sql
*/