# Module 4 — JOINs

## Why this matters

A JOIN does two important things:

1. It determines which rows survive.
2. It can change the grain of the result.

The SQL syntax is simple. The engineering challenge is choosing the join pattern that matches the clinical question.

## Core questions before every JOIN

- What is the left-side grain?
- What is the right-side grain?
- What is the expected cardinality?
- Which unmatched rows should survive?
- Does the JOIN change the study population?
- Does the JOIN change the output grain?
- Should right-table filters go in `ON` or `WHERE`?
- Do I need rows from the right-side table?
- Would `EXISTS` preserve the grain better?

## INNER JOIN

An `INNER JOIN` keeps only rows that match on both sides.

```sql
SELECT
    p.person_id,
    co.condition_occurrence_id
FROM person p
INNER JOIN condition_occurrence co
    ON co.person_id = p.person_id;
```

If a person has no matching condition row, that person is excluded from the result.

### Important implication

An `INNER JOIN` can change the study population.

## LEFT JOIN

A `LEFT JOIN` preserves every row from the left-side table.

```sql
SELECT
    po.procedure_occurrence_id,
    m.measurement_id
FROM procedure_occurrence po
LEFT JOIN measurement m
    ON m.person_id = po.person_id;
```

If a biopsy has no matching measurement, the biopsy remains and the measurement fields are `NULL`.

### Important distinction

A `LEFT JOIN` can preserve the population without preserving the grain.

If one biopsy matches four PSA measurements, the biopsy appears four times.

Population preservation and grain preservation are not the same thing.

## ON versus WHERE

For optional right-side data, qualification filters should generally go in the `ON` clause.

### Correct

```sql
SELECT
    po.procedure_occurrence_id,
    m.measurement_id
FROM procedure_occurrence po
LEFT JOIN measurement m
    ON m.person_id = po.person_id
   AND m.measurement_concept_id = 3004410;
```

This preserves procedures that do not have a matching PSA measurement.

### Potentially incorrect

```sql
SELECT
    po.procedure_occurrence_id,
    m.measurement_id
FROM procedure_occurrence po
LEFT JOIN measurement m
    ON m.person_id = po.person_id
WHERE m.measurement_concept_id = 3004410;
```

For procedures without a matching measurement, `m.measurement_concept_id` is `NULL`.

The `WHERE` clause removes those rows, so the query behaves like an inner join for that condition.

### Mental model

- `ON` determines which right-side rows qualify as matches.
- `WHERE` determines which completed result rows survive.

## EXISTS

Use `EXISTS` when the related table is needed only to qualify the anchor.

```sql
SELECT
    po.*
FROM procedure_occurrence po
WHERE EXISTS (
    SELECT 1
    FROM condition_occurrence co
    WHERE co.person_id = po.person_id
);
```

If a patient has several matching condition rows, the procedure is still returned only once.

`EXISTS` answers a Boolean question:

> Does at least one qualifying related row exist?

## SEMI JOIN

A semi join performs a similar job to `EXISTS`.

In Databricks SQL:

```sql
SELECT
    po.*
FROM procedure_occurrence po
LEFT SEMI JOIN condition_occurrence co
    ON co.person_id = po.person_id;
```

The right-side rows qualify the procedure but are not attached to the result.

## NOT EXISTS

Use `NOT EXISTS` when you want anchor rows with no qualifying related event.

```sql
SELECT
    po.*
FROM procedure_occurrence po
WHERE NOT EXISTS (
    SELECT 1
    FROM drug_exposure de
    WHERE de.person_id = po.person_id
);
```

This returns procedures for patients with no matching drug exposure.

## ANTI JOIN

An anti join is another way to return left-side rows that do not have a qualifying match.

In Databricks SQL:

```sql
SELECT
    po.*
FROM procedure_occurrence po
LEFT ANTI JOIN drug_exposure de
    ON de.person_id = po.person_id;
```

## One-to-many JOIN behavior

Suppose one biopsy has four eligible PSA measurements.

A direct join produces:

```text
biopsy_1 + psa_1
biopsy_1 + psa_2
biopsy_1 + psa_3
biopsy_1 + psa_4
```

The biopsy is still part of the population, but the output grain has changed.

If the intended grain is one row per biopsy, the matching PSA rows must be handled deliberately.

Possible strategies include:

- `ROW_NUMBER()` to select one PSA
- Aggregation
- `COUNT()`
- Arrays
- `EXISTS`

## Selecting one related event

Suppose the requirement is:

> For each prostate biopsy, select the most recent PSA from the prior 180 days.

Use a window function:

```sql
ROW_NUMBER() OVER (
    PARTITION BY po.procedure_occurrence_id
    ORDER BY
        m.measurement_date DESC,
        m.measurement_id DESC
) AS psa_rank
```

Then keep:

```sql
WHERE psa_rank = 1
```

### Mental model

- `PARTITION BY` defines which anchor event gets its own ranking group.
- `ORDER BY` determines which related event ranks first.

## DISTINCT warning

`DISTINCT` can hide a bad join.

If row counts unexpectedly increase, do not immediately add `DISTINCT`.

Investigate:

- Cardinality
- Join keys
- Missing temporal relationships
- Duplicate source rows
- Many-to-many relationships
- Whether `person_id` alone is sufficient to establish the clinical relationship

Use `DISTINCT` only when unique combinations are genuinely the intended output.

## JOIN validation

If the intended output grain is one row per biopsy, validate it explicitly.

```sql
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT procedure_occurrence_id) AS distinct_biopsy_count
FROM final_result;
```

Expected:

```text
row_count = distinct_biopsy_count
```

To identify duplicated anchor rows:

```sql
SELECT
    procedure_occurrence_id,
    COUNT(*) AS rows_per_biopsy
FROM final_result
GROUP BY procedure_occurrence_id
HAVING COUNT(*) > 1;
```

Expected result:

```text
0 rows
```

## Healthcare design example

Clinical requirement:

> Return every prostate biopsy, attach the most recent PSA within 180 days before the biopsy, and add a flag indicating whether treatment occurred within 90 days after the biopsy.

Design:

- Output grain: one row per prostate biopsy
- Anchor: qualifying `procedure_occurrence`
- PSA relationship: one biopsy to zero or many PSA measurements
- PSA join: `LEFT JOIN`
- PSA filters: placed in the `ON` clause
- PSA selection: `ROW_NUMBER()` per biopsy
- Treatment: `CASE WHEN EXISTS`
- Missing PSA: retain the biopsy and leave PSA fields `NULL`
- Validation: total rows must equal distinct biopsy IDs

## Key takeaways

1. JOINs change relationships, not just columns.
2. An `INNER JOIN` can change the study population.
3. A `LEFT JOIN` can preserve the population while still multiplying rows.
4. `ON` determines what matches; `WHERE` determines what survives.
5. Use `EXISTS` when you only need proof that a related row exists.
6. Always understand cardinality before joining.
7. Always validate that the final grain matches the intended grain.