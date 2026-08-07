/*
Module 6 — SQL Logical Query Processing

Clinical requirement:
Identify patients who had at least two prostate biopsies
after January 1, 2025.

Return one row per patient with:
- person_id
- total qualifying biopsy count

Only keep patients with at least two qualifying biopsies.

Order the final result from highest to lowest biopsy count.

Source grain:
One row per procedure occurrence.

Filtered grain:
One row per qualifying prostate biopsy.

Final output grain:
One row per patient.

Logical processing:

1. FROM
   Start with procedure_occurrence.

2. WHERE
   Keep qualifying prostate biopsy procedures after January 1, 2025.

3. GROUP BY
   Create one group per person.

4. HAVING
   Keep patient groups with at least two qualifying biopsies.

5. SELECT
   Return person_id and biopsy_count.

6. ORDER BY
   Sort from highest to lowest biopsy_count.
*/

SELECT
    po.person_id,
    COUNT(*) AS biopsy_count

FROM procedure_occurrence po

WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
  AND po.procedure_date > DATE '2025-01-01'

GROUP BY po.person_id

HAVING COUNT(*) >= 2

ORDER BY biopsy_count DESC;


/*
Exercise 2 — WHERE versus HAVING

Question:
Why is the following logic incorrect?

WHERE COUNT(*) >= 2

Answer:
WHERE is evaluated before GROUP BY.

At the WHERE stage, patient-level groups and COUNT(*)
have not yet been created.

Aggregate filtering belongs in HAVING.
*/


/*
Exercise 3 — SELECT alias timing

Question:
Why should biopsy_count not be referenced in WHERE?

Answer:
biopsy_count is created in the SELECT stage.

WHERE is logically evaluated before SELECT,
so the alias does not yet exist.

The alias can be used in ORDER BY because ORDER BY
occurs after SELECT.
*/


/*
Exercise 4 — Grain validation

The final result should contain one row per patient.
*/

WITH patient_biopsy_counts AS (

    SELECT
        po.person_id,
        COUNT(*) AS biopsy_count

    FROM procedure_occurrence po

    WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
      AND po.procedure_date > DATE '2025-01-01'

    GROUP BY po.person_id

    HAVING COUNT(*) >= 2
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT person_id) AS distinct_person_count
FROM patient_biopsy_counts;


/*
Expected validation:

row_count = distinct_person_count
*/


/*
Exercise 5 — Duplicate grain check

This query should return zero rows.
*/

WITH patient_biopsy_counts AS (

    SELECT
        po.person_id,
        COUNT(*) AS biopsy_count

    FROM procedure_occurrence po

    WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
      AND po.procedure_date > DATE '2025-01-01'

    GROUP BY po.person_id

    HAVING COUNT(*) >= 2
)

SELECT
    person_id,
    COUNT(*) AS rows_per_person
FROM patient_biopsy_counts
GROUP BY person_id
HAVING COUNT(*) > 1;