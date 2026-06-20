# Supply Chain Network Optimization using SQL

## Project Log

---

# Project Objective

The objective of this project was to design and implement a SQL-based decision support model for warehouse assignment within a multi-warehouse distribution network of a microchip manufacturer.

The project simulates a real-world Supply Chain Network Optimization problem by evaluating how customer orders can be assigned to warehouses while considering multiple operational constraints and minimizing total logistics costs.

The optimization process was developed entirely in PostgreSQL and follows a structured analytical workflow from raw data preparation to business evaluation of the proposed solution.

---

# Dataset Overview

The project uses historical operational data describing customer orders, warehouse capabilities and transportation rates.

Main datasets:

| Table            | Description                                             |
| ---------------- | ------------------------------------------------------- |
| OrderList        | Historical customer orders                              |
| ProductsPerPlant | Product availability by warehouse                       |
| VmiCustomers     | Customer–warehouse assignment constraints               |
| PlantPorts       | Warehouse–port mapping                                  |
| FreightRates     | Transportation rates by route, service level and weight |
| WhCapacities     | Daily warehouse processing capacity                     |
| WhCosts          | Warehouse handling cost per unit                        |

### Historical data

| Metric                             |                   Value |
| ---------------------------------- | ----------------------: |
| Historical orders                  |               **9,215** |
| Orders after excluding V44_3 / CRF |               **8,361** |
| Historical demand represented      | **One operational day** |

---

# Business Constraints

The optimization model incorporates several real operational constraints.

## Product availability

Products can only be shipped from warehouses where they are physically available.

| Metric                                   |             Value |
| ---------------------------------------- | ----------------: |
| Unique products                          |         **1,540** |
| Products available in only one warehouse | **1,271 (82.5%)** |

This significantly limits warehouse assignment flexibility.

---

## VMI constraints

Vendor Managed Inventory customers may only be served from predefined warehouses.

| Metric        |     Value |
| ------------- | --------: |
| VMI customers |    **10** |
| VMI orders    | **1,930** |

---

## Warehouse capacity

Warehouse capacities represent the maximum number of orders that can be processed during one operational day.

| Metric                         |            Value |
| ------------------------------ | ---------------: |
| Total daily warehouse capacity |        **5,791** |
| Daily demand (without CRF)     |        **8,361** |
| Capacity shortage              | **2,570 orders** |

---

## Historical network concentration

Historical order allocation is highly concentrated.

| Plant   | Historical orders |      Share |
| ------- | ----------------: | ---------: |
| PLANT03 |         **8,541** | **92.69%** |

This indicates strong dependence on a single warehouse.

---

# Optimization Workflow

The optimization was implemented as a sequence of SQL models.

## Step 00

Data preparation and standardization.

## Step 01

Data quality assessment and integrity validation.

## Step 02

Business constraint analysis.

## Step 03

Candidate Network Matrix

Applied constraints:

* Product availability
* VMI assignment
* Warehouse–Port mapping
* FreightRates availability

Results:

| Stage                             |    Orders |
| --------------------------------- | --------: |
| Historical orders (without CRF)   | **8,361** |
| After Products + VMI + PlantPorts | **7,475** |
| With available transport          | **7,300** |
| Without transport option          |   **175** |

The 175 infeasible orders were traced to a missing FreightRates lane:

**PORT03 → PORT09 → DTP**

---

## Step 04

Candidate Cost Matrix

Each feasible warehouse assignment was evaluated using:

* warehouse handling cost
* transportation cost
* total logistics cost

Results:

| Metric                         |          Value |
| ------------------------------ | -------------: |
| Candidate network combinations |     **57,354** |
| Costed alternatives            |     **54,791** |
| Missing costs                  |          **0** |
| Minimum total cost             |     **112.45** |
| Maximum total cost             | **131,919.77** |
| Average total cost             |     **717.99** |

---

## Step 05

Cost-only Optimization

For every order, the lowest-cost alternative was selected.

Results:

| Metric                 |            Value |
| ---------------------- | ---------------: |
| Orders optimized       |        **7,300** |
| Warehouse cost         | **8,703,392.70** |
| Transport cost         |    **85,033.70** |
| Total logistics cost   | **8,788,426.40** |
| Average cost per order |     **1,203.89** |

### Capacity assessment

The lowest-cost solution violates warehouse capacities.

| Plant   | Orders | Capacity |    Gap |
| ------- | -----: | -------: | -----: |
| PLANT03 |  4,709 |    1,013 | +3,696 |
| PLANT10 |  1,097 |      118 |   +979 |
| PLANT02 |    718 |      138 |   +580 |
| PLANT09 |     53 |       11 |    +42 |

---

## Step 06

Relocation Heuristic

Alternative warehouse assignments were generated for over-capacity warehouses.

### Relocation candidates

| Metric                         |      Value |
| ------------------------------ | ---------: |
| Orders with alternatives       |  **1,057** |
| Relocation options             | **10,448** |
| Relocatable orders             | **14.48%** |
| Average alternatives per order |   **9.88** |

### Alternative availability

| Plant   | Alternative % |
| ------- | ------------: |
| PLANT03 |     **1.23%** |
| PLANT10 |    **83.32%** |
| PLANT02 |     **4.46%** |
| PLANT09 |   **100.00%** |

The heuristic selected the cheapest feasible relocation for each eligible order.

Results:

| Current plant | Relocated orders |    Added cost |
| ------------- | ---------------: | ------------: |
| PLANT10       |          **914** |  **9,576.30** |
| PLANT09       |           **42** | **16,083.15** |

Total relocated orders:

**956**

Additional logistics cost:

**25,659.45**

Final logistics cost:

**8,814,085.85**

---

# Key Results

### Cost-only solution

* Lowest logistics cost identified.
* Operationally infeasible due to warehouse capacity violations.

### Capacity-aware heuristic

Successfully:

* eliminated PLANT09 overload,
* reduced PLANT10 overload by **914 orders**,

However:

* increased overload in PLANT03,
* increased overload in PLANT02.

The heuristic therefore improves local bottlenecks but does not produce a globally feasible solution.

---

# Key Findings

The project demonstrates several important characteristics of warehouse network optimization.

* Product availability is the strongest operational constraint.
* More than 82% of products are available in only one warehouse.
* Historical operations are highly concentrated in PLANT03.
* Cost minimization alone leads to operationally infeasible solutions.
* Warehouse capacity must be considered simultaneously with transportation costs.
* Simple relocation heuristics improve selected bottlenecks but cannot optimize the entire network.

---

# Final Conclusions

A complete SQL-based optimization workflow was successfully developed.

The project includes:

* data preparation,
* data validation,
* business constraint analysis,
* candidate network generation,
* logistics cost calculation,
* cost-only optimization,
* warehouse capacity assessment,
* heuristic relocation,
* final business evaluation.

The implemented heuristic confirms that local cost optimization is insufficient for solving a global warehouse assignment problem.

Although warehouse overload can be partially reduced, the solution remains globally infeasible because warehouse capacity constraints are not optimized simultaneously.

---

# Next Steps

The natural continuation of this project is the implementation of a mathematical optimization model.

A Linear Programming approach would allow simultaneous optimization of:

* warehouse assignment,
* transportation costs,
* warehouse capacities,
* and overall network feasibility.

This project therefore serves as a strong SQL-based analytical foundation for future Supply Chain Network Optimization using Operations Research techniques.

