/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 06_relocation_heuristic_v1.sql

Purpose:
    Build and evaluate a simple greedy relocation heuristic for selected
    over-capacity plants. The heuristic minimizes local extra cost and is used
    to demonstrate limitations of SQL-based local optimization.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


/*==============================================================================
1. BUILD RELOCATION CANDIDATES
==============================================================================*/

DROP TABLE IF EXISTS relocation_candidates;

CREATE TABLE relocation_candidates AS
WITH ranked_options AS (
    SELECT
        ccm.*,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY total_cost ASC, tpt_day_cnt ASC
        ) AS rn
    FROM candidate_cost_matrix ccm
),

best_option AS (
    SELECT *
    FROM ranked_options
    WHERE rn = 1
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
),

orders_to_relocate AS (
    SELECT
        bo.order_id,
        bo.candidate_plant AS current_plant,
        bo.total_cost AS current_total_cost
    FROM best_option bo
    JOIN over_capacity_plants ocp
        ON bo.candidate_plant = ocp.candidate_plant
),

alternative_options AS (
    SELECT
        ro.order_id,
        otr.current_plant,
        ro.candidate_plant AS alternative_plant,
        ro.candidate_port,
        ro.candidate_carrier,
        ro.mode_dsc,
        ro.tpt_day_cnt,
        otr.current_total_cost,
        ro.total_cost AS alternative_total_cost,
        ro.total_cost - otr.current_total_cost AS extra_cost
    FROM ranked_options ro
    JOIN orders_to_relocate otr
        ON ro.order_id = otr.order_id
    WHERE ro.candidate_plant <> otr.current_plant
)

SELECT *
FROM alternative_options;


/* Summary of available alternatives */
SELECT
    current_plant,
    COUNT(DISTINCT order_id) AS orders_with_alternatives,
    ROUND(MIN(extra_cost), 2) AS min_extra_cost,
    ROUND(MAX(extra_cost), 2) AS max_extra_cost,
    ROUND(AVG(extra_cost), 2) AS avg_extra_cost
FROM relocation_candidates
GROUP BY current_plant
ORDER BY orders_with_alternatives DESC;

SELECT
    COUNT(DISTINCT order_id) AS orders_with_alternatives,
    COUNT(*) AS relocation_options
FROM relocation_candidates;


/*
============================================================
Key Findings
============================================================

The relocation candidate table identifies all feasible
alternative warehouses for orders assigned to over-capacity plants.

Key observations:

- PLANT10 offers the largest relocation potential
  (914 orders with feasible alternatives).

- PLANT03 remains highly constrained.
  Only 58 orders can be reassigned despite severe over-capacity.

- The additional transportation and warehouse cost required
  for relocation varies substantially between plants.

The next step is to select the cheapest feasible relocation
for each order while reducing warehouse over-capacity.
============================================================
*/

/*==============================================================================
2. KEEP THE BEST ALTERNATIVE PER ORDER FOR PLANT09 AND PLANT10
==============================================================================*/

DROP TABLE IF EXISTS best_relocation_candidates;

CREATE TABLE best_relocation_candidates AS
WITH ranked_alternatives AS (
    SELECT
        rc.*,
        ROW_NUMBER() OVER (
            PARTITION BY rc.order_id
            ORDER BY rc.extra_cost ASC
        ) AS alternative_rank
    FROM relocation_candidates rc
    WHERE rc.current_plant IN ('PLANT09', 'PLANT10')
)

SELECT *
FROM ranked_alternatives
WHERE alternative_rank = 1;

SELECT
    current_plant,
    COUNT(*) AS orders_with_best_alternative,
    ROUND(MIN(extra_cost), 2) AS min_extra_cost,
    ROUND(MAX(extra_cost), 2) AS max_extra_cost,
    ROUND(AVG(extra_cost), 2) AS avg_extra_cost
FROM best_relocation_candidates
GROUP BY current_plant
ORDER BY current_plant;

/*
Expected result:
- PLANT09: 53 orders with best alternatives
- PLANT10: 914 orders with best alternatives

Interpretation:
For each order assigned to PLANT09 or PLANT10, the cheapest available
relocation option was selected. PLANT10 has a much lower average
relocation cost than PLANT09.
*/

/*==============================================================================
3. SELECT RELOCATIONS TO APPLY
==============================================================================*/

DROP TABLE IF EXISTS relocations_to_apply;

CREATE TABLE relocations_to_apply AS
WITH ranked_relocations AS (
    SELECT
        brc.*,
        ROW_NUMBER() OVER (
            PARTITION BY brc.current_plant
            ORDER BY brc.extra_cost ASC
        ) AS relocation_rank
    FROM best_relocation_candidates brc
)

SELECT *
FROM ranked_relocations
WHERE
    (current_plant = 'PLANT09' AND relocation_rank <= 42)
    OR
    (current_plant = 'PLANT10' AND relocation_rank <= 914);

SELECT
    current_plant,
    COUNT(*) AS relocated_orders,
    ROUND(SUM(extra_cost), 2) AS added_cost
FROM relocations_to_apply
GROUP BY current_plant;


/*==============================================================================
4. BUILD SOLUTION AFTER RELOCATION
==============================================================================*/

DROP TABLE IF EXISTS solution_after_relocation;

CREATE TABLE solution_after_relocation AS
SELECT
    os.order_id,
    os.product_id,
    os.customer,

    CASE
        WHEN rta.order_id IS NOT NULL THEN rta.alternative_plant
        ELSE os.candidate_plant
    END AS final_plant,

    CASE
        WHEN rta.order_id IS NOT NULL THEN rta.alternative_total_cost
        ELSE os.total_cost
    END AS final_total_cost,

    os.total_cost AS original_total_cost,

    CASE
        WHEN rta.order_id IS NOT NULL THEN rta.extra_cost
        ELSE 0
    END AS extra_cost,

    CASE
        WHEN rta.order_id IS NOT NULL THEN 1
        ELSE 0
    END AS relocated_flag

FROM optimal_solution_cost_only os
LEFT JOIN relocations_to_apply rta
    ON os.order_id = rta.order_id;


/*==============================================================================
5. VALIDATE HEURISTIC RESULT
==============================================================================*/

SELECT
    COUNT(*) AS orders,
    SUM(relocated_flag) AS relocated_orders,
    ROUND(SUM(original_total_cost), 2) AS original_total_cost,
    ROUND(SUM(final_total_cost), 2) AS final_total_cost,
    ROUND(SUM(extra_cost), 2) AS added_cost
FROM solution_after_relocation;

SELECT
    sar.final_plant,
    COUNT(*) AS final_orders,
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

SELECT
    current_plant,
    alternative_plant,
    COUNT(*) AS orders,
    ROUND(SUM(extra_cost), 2) AS extra_cost
FROM relocations_to_apply
GROUP BY current_plant, alternative_plant
ORDER BY current_plant, orders DESC;

/*
Key Findings:

The relocation heuristic applied 956 relocations with an additional
cost of 25,659.45.

The heuristic successfully eliminated the capacity gap for PLANT09
and significantly reduced the gap for PLANT10.

However, most relocated orders were moved to PLANT03, which was already
over capacity. This confirms that a local cost-based relocation heuristic
does not guarantee a globally feasible network solution.

This result justifies the need for a capacity-constrained optimization
model, such as Linear Programming, as the next stage of the project.
*/
