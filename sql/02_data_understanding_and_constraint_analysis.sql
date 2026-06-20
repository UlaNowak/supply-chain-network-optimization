/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 02_data_understanding_and_constraint_analysis.sql

Purpose:
    Explore historical demand, warehouse capacity, product constraints and VMI
    rules. These queries document the main business insights before modelling.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


/*==============================================================================
1. ORDERLIST OVERVIEW
==============================================================================*/

SELECT
    COUNT(*) AS total_orders
FROM orderlist;

SELECT
    COUNT(*) AS orders_without_v44_3
FROM orderlist
WHERE carrier <> 'V44_3';

SELECT
    COUNT(DISTINCT origin_port) AS origin_ports,
    COUNT(DISTINCT destination_port) AS destination_ports,
    COUNT(DISTINCT carrier) AS carriers,
    MIN(weight) AS min_weight,
    MAX(weight) AS max_weight
FROM orderlist;


/*==============================================================================
2. FREIGHTRATES OVERVIEW
==============================================================================*/

SELECT
    COUNT(*) AS freight_rate_rows,
    COUNT(DISTINCT orig_port_code) AS origin_ports,
    COUNT(DISTINCT dest_port_code) AS destination_ports,
    COUNT(DISTINCT carrier) AS carriers,
    MIN(min_weight_qty) AS min_weight_band,
    MAX(max_weight_qty) AS max_weight_band
FROM freightrates;

SELECT
    svc_code,
    COUNT(*) AS rows_count
FROM freightrates
GROUP BY svc_code
ORDER BY rows_count DESC;

SELECT
    mode_dsc,
    COUNT(*) AS rows_count
FROM freightrates
GROUP BY mode_dsc
ORDER BY rows_count DESC;

SELECT
    carrier_type,
    mode_dsc,
    svc_code,
    carrier,
    COUNT(*) AS rows_count
FROM freightrates
GROUP BY carrier, carrier_type, mode_dsc, svc_code
ORDER BY carrier_type, carrier, mode_dsc, svc_code;

/*
Expected interpretation:

- AIR is the dominant transport mode.
- Only two service levels are available (DTD, DTP).
- FreightRates contains multiple carriers for identical transport lanes,
  which provides alternative transport options during optimization.
*/


/*==============================================================================
3. HISTORICAL NETWORK CONCENTRATION
==============================================================================*/

SELECT
    plant_code,
    COUNT(*) AS order_volume,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS share_pct,
    SUM(unit_quantity) AS total_quantity,
    ROUND(SUM(weight),2) AS total_weight
FROM orderlist
GROUP BY plant_code
ORDER BY order_volume DESC;

/*
Business interpretation:

Historical order fulfillment was highly concentrated in PLANT03,
which handled over 92% of all historical orders.

This concentration suggests a potential opportunity to rebalance
the distribution network by evaluating alternative warehouses,
provided that product availability, VMI constraints,
transport feasibility and warehouse capacities are respected.
*/


/*==============================================================================
4. CAPACITY ANALYSIS
==============================================================================*/

SELECT
    SUM(daily_capacity) AS total_daily_capacity
FROM whcapacities;

SELECT
    plant_code,
    daily_capacity
FROM whcapacities
ORDER BY daily_capacity DESC;

/* Historical demand without V44_3 compared to total network capacity */
SELECT
    (SELECT COUNT(*) FROM orderlist WHERE carrier <> 'V44_3') AS demand_without_v44_3,
    (SELECT SUM(daily_capacity) FROM whcapacities) AS total_daily_capacity,
    (SELECT COUNT(*) FROM orderlist WHERE carrier <> 'V44_3')
        - (SELECT SUM(daily_capacity) FROM whcapacities) AS capacity_shortage;

/*
Business interpretation:

The historical dataset represents a single operational day.

After excluding CRF (V44_3) orders:

- Daily demand = 8,361 orders
- Total network daily capacity = 5,791 orders

The current warehouse network is therefore unable to process
all historical demand within one day, indicating a capacity
shortage of 2,570 orders.

Capacity constraints must therefore be considered during
network optimization.
*/

/*==============================================================================
5. PRODUCT CONSTRAINTS
==============================================================================*/

SELECT
    COUNT(*) AS rows_count,
    COUNT(DISTINCT product_id) AS unique_products
FROM productsperplant;

SELECT
    plant_code,
    COUNT(DISTINCT product_id) AS products_per_plant
FROM productsperplant
GROUP BY plant_code
ORDER BY products_per_plant DESC;

WITH product_plant_count AS (
    SELECT
        product_id,
        COUNT(DISTINCT plant_code) AS plants_per_product
    FROM productsperplant
    GROUP BY product_id
)
SELECT
    plants_per_product,
    COUNT(*) AS products
FROM product_plant_count
GROUP BY plants_per_product
ORDER BY plants_per_product;

/* Order volume by number of possible plants for ordered product */
WITH product_plant_count AS (
    SELECT
        product_id,
        COUNT(DISTINCT plant_code) AS plants_per_product
    FROM productsperplant
    GROUP BY product_id
)
SELECT
    ppc.plants_per_product,
    COUNT(o.order_id) AS order_volume
FROM orderlist o
JOIN product_plant_count ppc
    ON o.product_id = ppc.product_id
GROUP BY ppc.plants_per_product
ORDER BY ppc.plants_per_product;


/*==============================================================================
6. VMI ANALYSIS
==============================================================================*/

SELECT
    COUNT(DISTINCT customer) AS vmi_customers
FROM vmicustomers;

SELECT
    COUNT(DISTINCT o.order_id) AS vmi_orders_without_v44_3
FROM orderlist o
JOIN vmicustomers v
    ON o.customer = v.customer
WHERE o.carrier <> 'V44_3';

SELECT
    v.plant_code,
    COUNT(DISTINCT v.customer) AS vmi_customers
FROM vmicustomers v
GROUP BY v.plant_code
ORDER BY vmi_customers DESC;

/*
Business interpretation:

VMI customers introduce an additional allocation constraint.

Orders belonging to VMI customers can only be assigned
to warehouses explicitly listed in the VmiCustomers table.

This constraint is incorporated during candidate network generation.
*/
