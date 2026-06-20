# Project Assumptions

## 1. Dataset Scope

The `orderlist` table represents one operational day of historical demand.

Therefore, the number of non-CRF historical orders can be compared directly with daily warehouse capacity.

---

## 2. Historical Data vs Current Constraints

`orderlist` represents historical order fulfillment.

The remaining tables represent current network constraints:

* `productsperplant`
* `vmicustomers`
* `plantports`
* `freightrates`
* `whcapacities`
* `whcosts`

As a result, historical routing may not always be feasible under the current network setup.

---

## 3. Exclusion of V44_3 / CRF Orders

Carrier `V44_3` represents historical CRF orders.

CRF means Customer Referred Freight, where the customer arranges transportation independently.

For this reason:

* transportation cost is not calculated for these orders,
* V44_3 does not appear in the current `freightrates` table,
* these orders are excluded from the optimization model.

---

## 4. Warehouse Assignment Logic

An order can be assigned to a warehouse only if all required constraints are satisfied.

The main feasibility logic is:

1. The product must be available in the warehouse.
2. If the customer is a VMI customer, the warehouse must be allowed for that customer.
3. The warehouse must have an allowed port connection.
4. A transportation rate must exist for the candidate port, destination port, service level and weight band.

---

## 5. Product Availability Constraint

The `productsperplant` table defines which products can be shipped from each warehouse.

Products not listed for a warehouse are treated as unavailable at that warehouse.

---

## 6. VMI Constraint

For VMI customers, warehouse assignment is restricted to warehouses explicitly listed in the `vmicustomers` table.

For non-VMI customers, warehouse assignment depends on product availability and other network constraints.

---

## 7. PlantPorts Constraint

The `plantports` table defines which ports can be used by each warehouse.

A candidate warehouse must have at least one valid port connection to be considered in the candidate network.

---

## 8. FreightRates Constraint

A transport option is considered feasible only if there is a matching record in `freightrates` based on:

* origin port,
* destination port,
* service level,
* weight band.

The weight must fall between `min_weight_qty` and `max_weight_qty`.

---

## 9. Cost Calculation

Warehouse cost is calculated as:

```text
warehouse_cost = unit_quantity × cost_per_unit
```

Transportation cost is calculated as:

```text
transport_cost = max(weight × rate, min_cost)
```

Total cost is calculated as:

```text
total_cost = warehouse_cost + transport_cost
```

---

## 10. Capacity Constraint

Warehouse capacity is measured as the number of orders that can be processed per day.

It is not based on unit quantity or total weight.

---

## 11. Cost-only Optimization

The cost-only optimization selects the lowest `total_cost` option for each order.

This solution does not initially include warehouse capacity as a hard constraint.

The purpose of this step is to create a cost-minimizing baseline.

---

## 12. Relocation Heuristic

The relocation heuristic is a rule-based approach designed to reduce capacity overloads.

It works by:

1. identifying over-capacity warehouses,
2. finding alternative warehouse options for selected orders,
3. choosing the lowest-cost alternative for each eligible order,
4. applying selected relocations.

This heuristic does not globally optimize all assignments simultaneously.

---

## 13. Limitation of the SQL Heuristic

The heuristic minimizes relocation cost locally.

It does not prevent relocated orders from being assigned to warehouses that are already over capacity.

Therefore, it can improve selected bottlenecks but cannot guarantee a globally feasible solution.

This limitation justifies the next project stage: Linear Programming.

---

## 14. Non-standard Location Code

The `productsperplant` table contains one non-standard location code: `CND9`.

This code does not appear in:

* `plantports`,
* `whcapacities`,
* `whcosts`,
* `orderlist`.

It is identified during data validation and does not affect the final optimization model because it is naturally excluded from feasible candidate generation.

---

## 15. Data Preparation Assumptions

Before running analytical scripts, raw CSV files were imported into PostgreSQL and standardized using `00_data_preparation.sql`.

The preparation process includes:

* column renaming,
* data type conversion,
* trimming text values,
* cleaning currency and numeric fields,
* removing empty imported columns.

The final model uses standardized snake_case column names.
