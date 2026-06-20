/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 04_create_candidate_cost_matrix.sql

Purpose:
    Extend the feasible network matrix with warehouse, transportation and total
    costs for every available option.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


DROP TABLE IF EXISTS candidate_cost_matrix;

CREATE TABLE candidate_cost_matrix AS
WITH warehouse_cost AS (
    SELECT
        cnm.*,
        wc.cost_per_unit,
        cnm.unit_quantity * wc.cost_per_unit AS warehouse_cost
    FROM candidate_network_matrix cnm
    LEFT JOIN whcosts wc
        ON cnm.candidate_plant = wc.plant_code
),

transport_cost AS (
    SELECT
        *,
        CASE
            WHEN weight * rate < min_cost THEN min_cost
            ELSE weight * rate
        END AS transport_cost
    FROM warehouse_cost
)

SELECT
    *,
    warehouse_cost + transport_cost AS total_cost
FROM transport_cost
WHERE candidate_carrier IS NOT NULL;


/*==============================================================================
VALIDATION
==============================================================================*/

SELECT
    COUNT(*) AS rows_total,
    COUNT(warehouse_cost) AS rows_with_wh_cost,
    COUNT(transport_cost) AS rows_with_transport_cost,
    COUNT(total_cost) AS rows_with_total_cost,
    COUNT(*) - COUNT(warehouse_cost) AS rows_without_wh_cost,
    COUNT(*) - COUNT(transport_cost) AS rows_without_transport_cost,
    COUNT(*) - COUNT(total_cost) AS rows_without_total_cost,
    ROUND(MIN(total_cost), 2) AS min_total_cost,
    ROUND(MAX(total_cost), 2) AS max_total_cost,
    ROUND(AVG(total_cost),2) AS avg_total_cost
FROM candidate_cost_matrix;


SELECT
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS rows
FROM candidate_network_matrix;

SELECT
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS rows
FROM candidate_cost_matrix;
