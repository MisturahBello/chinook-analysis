# Chinook Music Store — SQL Business Analysis

A SQL analysis project using the [Chinook sample database](https://github.com/lerocha/chinook-database) — a fictional digital music store similar to iTunes. The goal was to answer real business questions a data analyst might face, using intermediate to advanced SQL.

**Tools:** SQL Server · SSMS  
**Techniques:** CTEs, window functions, conditional aggregation, date filtering, Pareto analysis

---

## The Business Questions

| # | Question | SQL Techniques |
|---|---|---|
| 1 | How big is the business? | Aggregation |
| 2 | Which genres make the most money? | CTE, `SUM() OVER()` |
| 3 | Who are our highest-value customers in the last 90 days? | CTE, `DATEADD`, `RANK()` |
| 4 | Which artists keep customers coming back? | Multi-level CTE, `CASE WHEN` |
| 5 | Is revenue growing month over month? | `LAG()`, running total |
| 6 | Which countries drive the most revenue? | `RANK()`, cumulative % |
| 7 | Do a few customers drive most of the revenue? | `NTILE()` decile bucketing |
| 8 | Which support reps handle the most valuable customers? | CTE, `RANK()` |

---

## Key Findings

**Genre revenue is heavily concentrated**  
Rock accounts for over 50% of all revenue on its own. Jazz, Metal, and Alternative/Punk are distant runners-up. A business this dependent on one genre has a real diversification risk.

**The top 10% of customers are disproportionately valuable**  
The decile analysis (Q7) shows the top spending tier contributes far more revenue than their numbers suggest. This group is the strongest candidate for a loyalty or VIP programme.

**A handful of countries generate most of the revenue**  
The Pareto analysis (Q6) shows that the USA leads by a significant margin, with just a few countries accounting for the majority of global sales.

**Repeat purchase rates vary widely by artist**  
Some artists achieve very high repeat rates among their buyers, meaning fans come back to buy more of their catalogue. These artists are good candidates to feature in recommendations or promotions.

**Revenue is volatile month to month**  
The MoM analysis (Q5) shows no strong seasonal trend — revenue swings up and down without a clear pattern, which suggests the business may benefit from more consistent marketing activity.

---

## How to Run This

1. Download the Chinook SQL Server script from the [latest release](https://github.com/lerocha/chinook-database/releases/latest) — look for `Chinook_SqlServer.sql`
2. Open SSMS and run the script to create and populate the database
3. Open `chinook_analysis.sql` and run each query against the `Chinook` database

---

## Database Schema

The Chinook database represents a digital music store with the following core tables:

```
Customer ──── Invoice ──── InvoiceLine ──── Track ──── Album ──── Artist
                                              │
                                            Genre
Employee ──── Customer (support rep relationship)
```

---

## What I Learned

- How to use **CTEs to break complex problems into readable steps** rather than nesting subqueries
- How **window functions** like `RANK()`, `LAG()`, `NTILE()`, and running totals work in practice on real data
- The difference between filtering with `WHERE` vs filtering after aggregation with `HAVING`
- How to build a **Pareto / cumulative % analysis** to identify revenue concentration
- How to define **dynamic date windows** in T-SQL using `DATEADD` rather than hardcoding dates
