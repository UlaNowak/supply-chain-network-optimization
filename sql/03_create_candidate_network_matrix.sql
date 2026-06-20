/*
===============================================================================
Project: Supply Chain Network Optimization
Script: 03_create_candidate_network_matrix.sql

Purpose:
    Build the feasibility model: all technically available order-plant-port-
    carrier combinations after applying ProductsPerPlant, VMI, PlantPorts and FreightRates.

Notes:
    - Run after 00_data_preparation.sql unless stated otherwise.
    - This script is part of the reviewed project structure.
===============================================================================
*/


DROP TABLE IF EXISTS candidate_network_matrix;

CREATE TABLE candidate_network_matrix AS
WITH orders_base AS (
    SELECT
        o.order_id,
        o.product_id,
        o.customer,
        o.plant_code AS historical_plant,
        o.origin_port AS historical_origin_port,
        o.destination_port,
        o.service_level,
        o.weight,
        o.unit_quantity,
        o.carrier AS historical_carrier
    FROM orderlist o
    WHERE o.carrier <> 'V44_3'
),

product_candidates AS (
    SELECT
        ob.*,
        p.plant_code AS candidate_plant
    FROM orders_base ob
    LEFT JOIN productsperplant p
        ON ob.product_id = p.product_id
),

vmi_candidates AS (
    SELECT
        pc.*,
        v.plant_code AS vmi_plant,
        CASE
            WHEN v.customer IS NOT NULL THEN 1
            ELSE 0
        END AS is_vmi
    FROM product_candidates pc
    LEFT JOIN vmicustomers v
        ON pc.customer = v.customer
),

wh_matrix AS (
    SELECT
        order_id,
        product_id,
        customer,
        historical_plant,
        historical_origin_port,
        destination_port,
        service_level,
        weight,
        unit_quantity,
        historical_carrier,
        candidate_plant,
        is_vmi,
        vmi_plant
    FROM vmi_candidates
    WHERE
        is_vmi = 0
        OR candidate_plant = vmi_plant
),

plant_port_matrix AS (
    SELECT
        wm.*,
        pp.port AS candidate_port
    FROM wh_matrix wm
    LEFT JOIN plantports pp
        ON wm.candidate_plant = pp.plant_code
),

transport_options AS (
    SELECT
        ppm.*,
        fr.carrier AS candidate_carrier,
        fr.mode_dsc,
        fr.svc_code,
        fr.min_weight_qty,
        fr.max_weight_qty,
        fr.rate,
        fr.min_cost,
        fr.tpt_day_cnt,
        fr.carrier_type
    FROM plant_port_matrix ppm
    LEFT JOIN freightrates fr
        ON ppm.candidate_port = fr.orig_port_code
        AND ppm.destination_port = fr.dest_port_code
        AND ppm.service_level = fr.svc_code
        AND ppm.weight BETWEEN fr.min_weight_qty AND fr.max_weight_qty
)

SELECT *
FROM transport_options;


/*==============================================================================
VALIDATION
==============================================================================*/

/* Order funnel after feasibility constraints */
SELECT
    COUNT(*) AS orders_total,
    SUM(CASE WHEN transport_options_count > 0 THEN 1 ELSE 0 END) AS orders_with_any_transport_rate,
    SUM(CASE WHEN transport_options_count = 0 THEN 1 ELSE 0 END) AS orders_without_any_transport_rate
FROM (
    SELECT
        order_id,
        COUNT(candidate_carrier) AS transport_options_count
    FROM candidate_network_matrix
    GROUP BY order_id
) x;

/* Diagnose orders without any available transport rate */
SELECT
    customer,
    COUNT(DISTINCT order_id) AS orders
FROM candidate_network_matrix
WHERE order_id IN (
    SELECT order_id
    FROM candidate_network_matrix
    GROUP BY order_id
    HAVING COUNT(candidate_carrier) = 0
)
GROUP BY customer
ORDER BY orders DESC;

SELECT DISTINCT
    customer,
    candidate_plant,
    candidate_port,
    destination_port,
    service_level
FROM candidate_network_matrix
WHERE order_id IN (
    SELECT order_id
    FROM candidate_network_matrix
    GROUP BY order_id
    HAVING COUNT(candidate_carrier) = 0
)
ORDER BY customer, candidate_plant, candidate_port, service_level;

/* FreightRates coverage for PORT09 lanes */
SELECT DISTINCT
    orig_port_code,
    dest_port_code,
    svc_code
FROM freightrates
WHERE dest_port_code = 'PORT09'
ORDER BY orig_port_code, svc_code;

/*
Expected result:
- 7,475 orders pass product, VMI and PlantPorts feasibility checks.
- 7,300 orders have at least one available transport option.
- 175 orders have no available transport rate.

The 175 infeasible transport cases are concentrated in 3 VMI customers.
They are later diagnosed as PLANT02 / PORT03 / PORT09 / DTP cases,
where FreightRates does not contain the required service-level lane.
*/
