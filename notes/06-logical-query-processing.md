# Module 6 — SQL Logical Query Processing

## Why this matters

SQL is written in one order but logically evaluated in another.

Understanding that logical order explains many common SQL behaviors, including:

- Why a `SELECT` alias often cannot be used in `WHERE`
- Why `HAVING` exists
- Why a `LEFT JOIN` can behave like an `INNER JOIN`
- Why window functions are often filtered in an outer query
- Why `GROUP BY` changes the grain of a dataset

## Simplified logical processing order

```text
1. FROM
2. JOIN / ON
3. WHERE
4. GROUP BY
5. HAVING
6. Window functions
7. SELECT
8. DISTINCT
9. ORDER BY
10. LIMIT
```

## FROM

`FROM` defines the starting dataset.

```sql
FROM procedure_occurrence po
```

At this stage, SQL begins with the rows from `procedure_occurrence`.

## JOIN / ON

JOIN logic determines which rows from related tables match.

```sql
FROM procedure_occurrence po
LEFT JOIN measurement m
    ON m.person_id = po.person_id
   AND m.measurement_date <= po.procedure_date
```

The `ON` clause determines which measurement rows qualify as matches.

This connects to the earlier JOIN rule:

- `ON` controls matching
- `WHERE` controls which completed rows survive

## WHERE

`WHERE` filters rows before grouping.

```sql
WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
  AND po.procedure_date > DATE '2025-01-01'
```

After this step, only qualifying procedure rows remain.

### Important implication

If a right-side field from a `LEFT JOIN` is filtered in `WHERE`, unmatched rows with `NULL` values can be removed.

Example:

```sql
LEFT JOIN measurement m
    ON m.person_id = po.person_id
WHERE m.measurement_concept_id = 3004410
```

This can effectively turn the logic into an inner join for that condition.

## GROUP BY

`GROUP BY` changes the grain of the result.

Example:

```sql
SELECT
    person_id,
    COUNT(*) AS biopsy_count
FROM procedure_occurrence
GROUP BY person_id;
```

Before grouping:

```text
One row per procedure occurrence
```

After grouping:

```text
One row per person
```

### Key rule

The columns in `GROUP BY` largely determine the new grain of the result.

## HAVING

`HAVING` filters groups after aggregation.

Example:

```sql
SELECT
    person_id,
    COUNT(*) AS biopsy_count
FROM procedure_occurrence
GROUP BY person_id
HAVING COUNT(*) >= 2;
```

This means:

> Keep only patient groups containing at least two qualifying procedure rows.

### WHERE versus HAVING

```text
WHERE
filters individual rows before grouping

HAVING
filters groups after grouping
```

This is why the following is invalid:

```sql
WHERE COUNT(*) >= 2
```

At the `WHERE` stage, the groups do not exist yet.

## Window functions

Window functions add calculations across related rows without collapsing them.

Example:

```sql
ROW_NUMBER() OVER (
    PARTITION BY person_id
    ORDER BY procedure_date
) AS biopsy_rank
```

Unlike `GROUP BY`, the original procedure rows remain.

### GROUP BY versus window functions

`GROUP BY`:

```text
Collapses rows
```

Window functions:

```text
Preserve rows and add information
```

## Filtering window function results

A window-function result is not available during the `WHERE` stage.

This pattern is therefore usually invalid:

```sql
SELECT
    person_id,
    procedure_occurrence_id,
    ROW_NUMBER() OVER (
        PARTITION BY person_id
        ORDER BY procedure_date
    ) AS rn
FROM procedure_occurrence
WHERE rn = 1;
```

Instead, calculate the window function first:

```sql
WITH ranked AS (
    SELECT
        person_id,
        procedure_occurrence_id,
        procedure_date,

        ROW_NUMBER() OVER (
            PARTITION BY person_id
            ORDER BY procedure_date
        ) AS rn

    FROM procedure_occurrence
)

SELECT *
FROM ranked
WHERE rn = 1;
```

The outer query can filter `rn` because the inner query has already created it.

## SELECT

`SELECT` constructs the final output expressions.

Example:

```sql
SELECT
    person_id,
    COUNT(*) AS biopsy_count
```

The alias:

```text
biopsy_count
```

is created at the `SELECT` stage.

This explains why a `SELECT` alias usually cannot be referenced in `WHERE`.

Example:

```sql
SELECT
    DATEDIFF(procedure_date, condition_start_date) AS days_from_diagnosis
FROM ...
WHERE days_from_diagnosis >= 0;
```

Logically, `WHERE` happens before `SELECT`, so the alias does not yet exist.

## DISTINCT

`DISTINCT` operates after the selected expressions have been produced.

```sql
SELECT DISTINCT
    person_id
FROM procedure_occurrence;
```

This removes duplicate selected combinations.

### Warning

`DISTINCT` can make a result look correct without fixing the upstream relationship that caused row multiplication.

## ORDER BY

`ORDER BY` happens after `SELECT`.

This is why a `SELECT` alias can commonly be used in `ORDER BY`.

```sql
SELECT
    person_id,
    COUNT(*) AS biopsy_count
FROM procedure_occurrence
GROUP BY person_id
ORDER BY biopsy_count DESC;
```

## LIMIT

`LIMIT` is applied near the end of query processing.

```sql
ORDER BY biopsy_count DESC
LIMIT 10
```

This means:

> Sort the result, then return the first 10 rows.

Without `ORDER BY`, `LIMIT` does not guarantee a meaningful ordering.

## Healthcare example

Clinical requirement:

> Identify patients who had at least two prostate biopsies after January 1, 2025. Return one row per patient with the total qualifying biopsy count and order patients from highest to lowest count.

```sql
SELECT
    po.person_id,
    COUNT(*) AS biopsy_count
FROM procedure_occurrence po
WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
  AND po.procedure_date > DATE '2025-01-01'
GROUP BY po.person_id
HAVING COUNT(*) >= 2
ORDER BY biopsy_count DESC;
```

## Logical processing of the healthcare example

```text
FROM
Start with procedure_occurrence.

↓

WHERE
Keep qualifying prostate biopsy procedures after January 1, 2025.

↓

GROUP BY
Create one group per person.

↓

HAVING
Keep only patient groups with at least two qualifying biopsies.

↓

SELECT
Return person_id and biopsy_count.

↓

ORDER BY
Sort from highest to lowest biopsy_count.
```

## Grain evolution

```text
procedure_occurrence
One row per procedure occurrence

↓

WHERE
One row per qualifying prostate biopsy

↓

GROUP BY person_id
One row per patient
```

## Key takeaways

1. SQL syntax order is not the same as logical processing order.
2. `WHERE` filters rows before aggregation.
3. `GROUP BY` changes the grain.
4. `HAVING` filters aggregated groups.
5. Window functions preserve rows rather than collapsing them.
6. `SELECT` aliases are created after `WHERE`.
7. `ORDER BY` can usually use `SELECT` aliases because it occurs later.
8. Always track how grain changes as a query moves through its logical stages.