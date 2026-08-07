# Module 5 — EXISTS and Set-Based Filtering

## Why this matters

Many healthcare cohort rules only require us to determine whether a related event exists.

If we do not need columns from the related table, joining all matching rows can unnecessarily multiply the output.

The key design question is:

> Do I need the related rows, or only proof that at least one qualifying row exists?

## EXISTS

`EXISTS` answers a Boolean question:

> Does at least one qualifying related row exist?

Example:

```sql
SELECT
    po.person_id,
    po.procedure_occurrence_id,
    po.procedure_date
FROM procedure_occurrence po
WHERE EXISTS (
    SELECT 1
    FROM condition_occurrence co
    WHERE co.person_id = po.person_id
      AND co.condition_start_date <= po.procedure_date
);
```

The condition rows are used to qualify the procedure but are not attached to the result.

This helps preserve the anchor grain.

## Why SELECT 1 is used

Inside an `EXISTS` subquery, the selected value does not matter.

```sql
SELECT 1
```

is commonly used because it communicates that the query only needs to determine whether a row exists.

## Correlated subquery

An `EXISTS` query often references a value from the outer query.

Example:

```sql
co.person_id = po.person_id
```

This makes the subquery correlated to the anchor row.

Conceptually, SQL asks:

> For this biopsy, does at least one qualifying condition row exist for the same patient?

## JOIN versus EXISTS

Use a JOIN when related rows or columns are needed in the result.

Use `EXISTS` when the related table is only being used for qualification.

Example:

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

If the patient has several matching condition rows, the biopsy is still returned once.

## NOT EXISTS

`NOT EXISTS` returns anchor rows when no qualifying related row exists.

Example:

```sql
SELECT
    po.*
FROM procedure_occurrence po
WHERE NOT EXISTS (
    SELECT 1
    FROM drug_exposure de
    WHERE de.person_id = po.person_id
      AND de.drug_exposure_start_date
          BETWEEN DATE_SUB(po.procedure_date, 30)
              AND po.procedure_date
);
```

This is useful for exclusion criteria.

## EXISTS as an inclusion rule

Example clinical rule:

> Include biopsies for patients with prostate cancer diagnosed on or before the biopsy date.

Pattern:

```sql
WHERE EXISTS (
    SELECT 1
    FROM condition_occurrence co
    WHERE co.person_id = po.person_id
      AND co.condition_start_date <= po.procedure_date
)
```

This changes which biopsy rows remain in the population.

## NOT EXISTS as an exclusion rule

Example clinical rule:

> Exclude biopsies if ADT occurred within 30 days before the biopsy.

Pattern:

```sql
AND NOT EXISTS (
    SELECT 1
    FROM drug_exposure de
    WHERE de.person_id = po.person_id
      AND de.drug_exposure_start_date
          BETWEEN DATE_SUB(po.procedure_date, 30)
              AND po.procedure_date
)
```

This also changes the population.

## CASE WHEN EXISTS

Sometimes a related event should not filter the population.

Instead, it should create a flag.

Example:

```sql
CASE
    WHEN EXISTS (
        SELECT 1
        FROM drug_exposure de
        WHERE de.person_id = po.person_id
          AND de.drug_exposure_start_date
              BETWEEN po.procedure_date
                  AND DATE_ADD(po.procedure_date, 90)
    )
    THEN 1
    ELSE 0
END AS has_adt_within_90_days
```

This preserves every qualifying biopsy and adds information.

## WHERE EXISTS versus CASE WHEN EXISTS

`WHERE EXISTS`:

- Changes the population
- Keeps only anchor rows with a qualifying match

`CASE WHEN EXISTS`:

- Preserves the population
- Adds a Boolean indicator

## SEMI JOIN

A semi join performs a similar function to `EXISTS`.

In Databricks SQL:

```sql
SELECT
    po.*
FROM procedure_occurrence po
LEFT SEMI JOIN condition_occurrence co
    ON co.person_id = po.person_id
   AND co.condition_start_date <= po.procedure_date;
```

The right-side rows qualify the left-side rows but are not attached to the result.

## ANTI JOIN

An anti join performs a similar function to `NOT EXISTS`.

In Databricks SQL:

```sql
SELECT
    po.*
FROM procedure_occurrence po
LEFT ANTI JOIN drug_exposure de
    ON de.person_id = po.person_id
   AND de.drug_exposure_start_date
       BETWEEN DATE_SUB(po.procedure_date, 30)
           AND po.procedure_date;
```

This returns left-side rows with no qualifying match.

## IN versus EXISTS

A query can sometimes use `IN`:

```sql
WHERE po.person_id IN (
    SELECT co.person_id
    FROM condition_occurrence co
)
```

But `EXISTS` often expresses correlated healthcare logic more clearly:

```sql
WHERE EXISTS (
    SELECT 1
    FROM condition_occurrence co
    WHERE co.person_id = po.person_id
      AND co.condition_start_date <= po.procedure_date
)
```

`EXISTS` is especially useful when the qualification depends on anchor-specific dates or other correlated conditions.

## Healthcare design pattern

Clinical requirement:

> Return prostate biopsies for patients with prostate cancer, exclude biopsies with recent ADT, and add a flag for ADT after biopsy.

Design:

- Output grain: one row per prostate biopsy
- Anchor: qualifying prostate biopsy
- Prostate cancer diagnosis: `EXISTS`
- Prior ADT exclusion: `NOT EXISTS`
- Post-biopsy ADT flag: `CASE WHEN EXISTS`

Conceptually:

```text
Biopsy
  |
  |-- prostate cancer diagnosis → EXISTS
  |
  |-- prior ADT exclusion → NOT EXISTS
  |
  |-- post-biopsy ADT → CASE WHEN EXISTS
```

## Key takeaways

1. Do not JOIN a table when you only need to know whether a row exists.
2. `EXISTS` is useful for inclusion criteria.
3. `NOT EXISTS` is useful for exclusion criteria.
4. `CASE WHEN EXISTS` is useful for flags.
5. `EXISTS` and `NOT EXISTS` help preserve anchor grain.
6. Correlated subqueries allow event-specific temporal logic.
7. Always distinguish population-changing logic from enrichment logic.