/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 05_cost_only_optimization_and_capacity_check.sql

Purpose:
    Select the lowest-cost option for every order and validate whether the
    cost-only solution respects warehouse capacity constraints.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


DROP TABLE IF EXISTS optimal_solution_cost_only;

CREATE TABLE optimal_solution_cost_only AS
WITH ranked_options AS (
    SELECT
        ccm.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY total_cost ASC, tpt_day_cnt ASC
        ) AS best_option
    FROM candidate_cost_matrix ccm
)

SELECT *
FROM ranked_options
WHERE best_option = 1;


/*==============================================================================
1. COST-ONLY SOLUTION SUMMARY
==============================================================================*/

SELECT
    COUNT(*) AS orders,
    SUM(warehouse_cost) AS warehouse_cost,
    ROUND(SUM(transport_cost), 2) AS transport_cost,
    ROUND(SUM(total_cost), 2) AS total_cost,
    ROUND(AVG(total_cost), 2) AS avg_cost_per_order
FROM optimal_solution_cost_only;


/*==============================================================================
2. CAPACITY ASSESSMENT OF THE COST-OPTIMAL SOLUTION
==============================================================================*/

SELECT
    os.candidate_plant,
    COUNT(*) AS selected_orders,
    wc.daily_capacity,
    COUNT(*) - wc.daily_capacity AS capacity_gap,
    CASE
        WHEN COUNT(*) > wc.daily_capacity THEN 'over_capacity'
        ELSE 'within_capacity'
    END AS capacity_status,
    SUM(os.warehouse_cost) AS warehouse_cost,
    ROUND(SUM(os.transport_cost), 2) AS transport_cost,
    ROUND(SUM(os.total_cost), 2) AS total_cost
FROM optimal_solution_cost_only os
LEFT JOIN whcapacities wc
    ON os.candidate_plant = wc.plant_code
GROUP BY os.candidate_plant, wc.daily_capacity
ORDER BY capacity_gap DESC;


/*==============================================================================
3. ALTERNATIVES AVAILABILITY FOR OVER-CAPACITY PLANTS
==============================================================================*/

WITH plant_options AS (
    SELECT
        order_id,
        COUNT(DISTINCT candidate_plant) AS plant_options
    FROM candidate_cost_matrix
    GROUP BY order_id
),

best_option AS (
    SELECT
        os.*,
        po.plant_options
    FROM optimal_solution_cost_only os
    LEFT JOIN plant_options po
        ON os.order_id = po.order_id
),

plant_load AS (
    SELECT
        candidate_plant,
        COUNT(*) AS selected_orders
    FROM best_option
    GROUP BY candidate_plant
),

over_capacity_plants AS (
    SELECT
        pl.candidate_plant,
        pl.selected_orders,
        wc.daily_capacity,
        pl.selected_orders - wc.daily_capacity AS capacity_gap
    FROM plant_load pl
    JOIN whcapacities wc
        ON pl.candidate_plant = wc.plant_code
    WHERE pl.selected_orders > wc.daily_capacity
)

SELECT
    bo.candidate_plant,
    COUNT(*) AS selected_orders,
    SUM(CASE WHEN bo.plant_options = 1 THEN 1 ELSE 0 END) AS no_alternative_orders,
    SUM(CASE WHEN bo.plant_options > 1 THEN 1 ELSE 0 END) AS with_alternative_orders,
    ROUND(100.0 * SUM(CASE WHEN bo.plant_options > 1 THEN 1 ELSE 0 END)/ COUNT(*), 2) as alternative_perc
FROM best_option bo
JOIN over_capacity_plants ocp
    ON bo.candidate_plant = ocp.candidate_plant
GROUP BY bo.candidate_plant
ORDER BY selected_orders DESC;

/*
============================================================
Summary

The cost-only optimization confirms that the lowest-cost solution
is not operationally feasible.

Key observations:

- Four warehouses exceed their daily capacity.
- PLANT03 processes nearly 65% of all selected orders and exceeds
  its capacity by 3,696 orders.
- PLANT10 has the highest relocation potential:
    • 914 of 1,097 orders (83.32%) have at least one alternative warehouse.
- PLANT03 has very limited flexibility:
    • only 58 of 4,709 orders (1.23%) can be relocated.
- Capacity constraints must therefore be incorporated into the
  optimization process.

The next step is to identify the cheapest feasible relocation
options for orders assigned to over-capacity warehouses.
============================================================
*/
