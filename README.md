# Supply Chain Network Optimization using SQL

## Project Overview

This project presents a SQL-based supply chain network optimization analysis focused on warehouse assignment, logistics cost calculation and capacity evaluation.

The goal was to determine the lowest-cost warehouse allocation for customer orders while considering operational constraints such as:

* product availability,
* VMI rules,
* warehouse-port connections,
* transportation rates,
* warehouse capacity.

The project was developed in PostgreSQL as an end-to-end analytical workflow: from data preparation and validation to cost optimization, capacity check and relocation heuristic.

---

## Business Problem

The historical network was highly concentrated in one warehouse, while the current supply chain setup includes several constraints that limit possible order allocation.

The main questions were:

* Which orders can be fulfilled under current network constraints?
* What is the lowest-cost warehouse assignment?
* Does the cost-optimal solution respect warehouse capacity?
* Can a simple relocation heuristic reduce warehouse overload?
* Why is Linear Programming needed as the next step?

---

## Tools

* PostgreSQL
* SQL
* DBeaver
* GitHub

---

## Repository Structure

```text
supply-chain-network-optimization/
│
├── README.md
│
├── sql/
│   ├── 00_data_preparation.sql
│   ├── 01_data_model_assessment.sql
│   ├── 02_data_understanding.sql
│   ├── 03_candidate_network_matrix.sql
│   ├── 04_candidate_cost_matrix.sql
│   ├── 05_cost_only_optimization.sql
│   ├── 06_relocation_heuristic.sql
│   └── 07_final_summary.sql
│
├── documentation/
│   ├── PROJECT_LOG.md
│   └── assumptions.md
│
├── data/
│   ├── raw/
│   └── prepared/
│
└── images/
    └── .gitkeep
```

---

## SQL Workflow

| Step | Description                          |
| ---- | ------------------------------------ |
| 00   | Data preparation and standardization |
| 01   | Data model assessment                |
| 02   | Business constraint analysis         |
| 03   | Candidate network matrix             |
| 04   | Candidate cost matrix                |
| 05   | Cost-only optimization               |
| 06   | Relocation heuristic                 |
| 07   | Final summary and conclusions        |

---

## Key Results

| Metric                              |        Value |
| ----------------------------------- | -----------: |
| Historical orders                   |        9,215 |
| Orders after excluding CRF          |        8,361 |
| Candidate network combinations      |       57,354 |
| Costed alternatives                 |       54,791 |
| Optimized orders                    |        7,300 |
| Transport cost                      |    85,033.70 |
| Total cost – cost-only solution     | 8,788,426.40 |
| Relocation options                  |       10,448 |
| Orders with relocation alternatives |        1,057 |
| Added cost after relocation         |    25,659.45 |
| Final cost after relocation         | 8,814,085.85 |

---

## Main Findings

The cost-only solution minimized logistics costs but violated warehouse capacity limits.

The relocation heuristic reduced selected overloads, especially for PLANT09 and PLANT10, but did not produce a globally feasible solution because most relocated orders were assigned to warehouses that were already over capacity.

This confirmed that local cost minimization is not sufficient for a full network optimization problem.

---

## Final Conclusion

SQL was used to build a complete analytical workflow for supply chain feasibility and cost optimization.

The project shows how operational constraints can be modeled in SQL and how cost-based decisions can be evaluated against capacity limitations.

The next step is to implement a Linear Programming model in Python to optimize warehouse assignment and capacity constraints simultaneously.

---

## Documentation

Detailed project documentation is available in:

* `documentation/PROJECT_LOG.md`
* `documentation/assumptions.md`
