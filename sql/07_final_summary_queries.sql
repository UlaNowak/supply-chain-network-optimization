/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 07_final_summary_queries.sql

Purpose:
    Final aggregate queries intended for README, project_log and Power BI storytelling.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


/*==============================================================================
1. ORDER FUNNEL
==============================================================================*/

SELECT * FROM (
	SELECT '01_all_historical_orders' AS stage, COUNT(*) AS orders FROM orderlist
	UNION ALL
	SELECT '02_without_v44_3', COUNT(*) FROM orderlist WHERE carrier <> 'V44_3'
	UNION ALL
	SELECT '03_after_product_vmi_plantports', COUNT(DISTINCT order_id) FROM candidate_network_matrix
	UNION ALL
	SELECT '04_with_transport_option', COUNT(DISTINCT order_id) FROM candidate_cost_matrix
	UNION ALL
	SELECT '05_without_transport_option',
       (SELECT COUNT(DISTINCT order_id) FROM candidate_network_matrix)
       - (SELECT COUNT(DISTINCT order_id) FROM candidate_cost_matrix)) as x 
ORDER BY 2 DESC


/*==============================================================================
2. COST-ONLY SOLUTION SUMMARY
==============================================================================*/

SELECT
    COUNT(*) AS orders,
    SUM(warehouse_cost) AS warehouse_cost,
    ROUND(SUM(transport_cost), 2) AS transport_cost,
    ROUND(SUM(total_cost), 2) AS total_cost,
    ROUND(AVG(total_cost), 2) AS avg_cost_per_order
FROM optimal_solution_cost_only;


/*==============================================================================
3. CAPACITY BEFORE RELOCATION
==============================================================================*/

SELECT
    os.candidate_plant AS plant_code,
    COUNT(*) AS orders,
    wc.daily_capacity,
    COUNT(*) - wc.daily_capacity AS capacity_gap,
    CASE
        WHEN COUNT(*) > wc.daily_capacity THEN 'over_capacity'
        ELSE 'within_capacity'
    END AS capacity_status
FROM optimal_solution_cost_only os
LEFT JOIN whcapacities wc
    ON os.candidate_plant = wc.plant_code
GROUP BY os.candidate_plant, wc.daily_capacity
ORDER BY capacity_gap DESC;


/*==============================================================================
4. RELOCATION SUMMARY
==============================================================================*/

SELECT
    current_plant,
    alternative_plant,
    COUNT(*) AS relocated_orders,
    ROUND(SUM(extra_cost), 2) AS added_cost
FROM relocations_to_apply
GROUP BY current_plant, alternative_plant
ORDER BY current_plant, relocated_orders DESC;


/*==============================================================================
5. CAPACITY AFTER RELOCATION
==============================================================================*/

SELECT
    sar.final_plant AS plant_code,
    COUNT(*) AS orders,
    wc.daily_capacity,
    COUNT(*) - wc.daily_capacity AS capacity_gap,
    CASE
        WHEN COUNT(*) > wc.daily_capacity THEN 'over_capacity'
        ELSE 'within_capacity'
    END AS capacity_status
FROM solution_after_relocation sar
LEFT JOIN whcapacities wc
    ON sar.final_plant = wc.plant_code
GROUP BY sar.final_plant, wc.daily_capacity
ORDER BY capacity_gap DESC;


/*==============================================================================
6. FINAL COST COMPARISON
==============================================================================*/

SELECT
    'cost_only_solution' AS scenario,
    COUNT(*) AS orders,
    ROUND(SUM(total_cost), 2) AS total_cost
FROM optimal_solution_cost_only
UNION ALL
SELECT
    'after_relocation_v1',
    COUNT(*),
    ROUND(SUM(final_total_cost), 2)
FROM solution_after_relocation;



/*
============================================================
FINAL BUSINESS CONCLUSIONS
============================================================

The optimization process successfully generated the lowest-cost
warehouse assignment while respecting product availability,
VMI restrictions, transport feasibility and warehouse costs.

The cost-only solution minimized total logistics costs but revealed
significant capacity violations in four warehouses, indicating that
cost optimization alone is insufficient for operational planning.

A heuristic relocation approach was then applied to reduce
warehouse over-capacity by selecting the lowest-cost alternative
warehouse for eligible orders.

Results showed that:
- PLANT09 capacity was fully resolved.
- PLANT10 capacity overload was significantly reduced.
- Total logistics cost increased by only 25,659.45 (+0.29%).
- However, most relocated orders were reassigned to PLANT03,
  which further increased its existing overload.

These findings demonstrate that local, cost-based relocation
heuristics improve individual bottlenecks but do not guarantee
a globally feasible network configuration.

A capacity-constrained optimization model (e.g. Linear Programming)
would be required to simultaneously minimize total logistics costs
while respecting warehouse capacity constraints across the entire
distribution network.

============================================================
Project outcome:
A complete SQL-based optimization workflow was developed, including:
- data preparation and validation,
- business constraint analysis,
- candidate network generation,
- logistics cost calculation,
- cost-only optimization,
- heuristic relocation,
- and final business evaluation.
============================================================
*/
