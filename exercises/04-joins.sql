/*
Module 4 Exercise: JOIN behavior

Clinical question:
Return every prostate biopsy and attach eligible PSA measurements
from the prior 180 days, while preserving biopsies without PSA.

Before writing SQL, define:

1. Output grain:
2. Anchor event:
3. Left-side grain:
4. Right-side grain:
5. Expected cardinality:
6. JOIN type:
7. ON-clause filters:
8. Validation query:
*/

/*
Module 4 Exercise: JOIN behavior

Clinical question:
Return every prostate biopsy and attach eligible PSA measurements
from the prior 180 days, while preserving biopsies without PSA.

1. Output grain:
One row per prostate biopsy after selecting at most one PSA.

2. Anchor event:
Qualifying prostate biopsy.

3. Left-side grain:
One row per biopsy procedure.

4. Right-side grain:
One row per PSA measurement.

5. Expected cardinality:
One biopsy to zero or many PSA measurements.

6. JOIN type:
LEFT JOIN, because biopsies without PSA must remain.

7. ON-clause filters:
- Same person
- PSA concept
- PSA date on or before biopsy
- PSA date no more than 180 days before biopsy

8. Validation query:
Confirm total rows equal distinct biopsy IDs.
*/

WITH biopsy_psa_candidates AS (
    SELECT
        po.person_id,
        po.procedure_occurrence_id,
        po.procedure_date,
        m.measurement_id,
        m.measurement_date,
        m.value_as_number,
        ROW_NUMBER() OVER (
            PARTITION BY po.procedure_occurrence_id
            ORDER BY
                m.measurement_date DESC,
                m.measurement_id DESC
        ) AS psa_rank
    FROM procedure_occurrence po
    LEFT JOIN measurement m
        ON m.person_id = po.person_id
       AND m.measurement_concept_id = 3004410
       AND m.measurement_date BETWEEN DATE_SUB(po.procedure_date, 180)
                                  AND po.procedure_date
)

SELECT
    person_id,
    procedure_occurrence_id,
    procedure_date,
    measurement_id,
    measurement_date,
    value_as_number
FROM biopsy_psa_candidates
WHERE psa_rank = 1;
-- validation query -- 
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT procedure_occurrence_id) AS distinct_biopsy_count
FROM biopsy_psa_candidates
WHERE psa_rank = 1;



---

## `exercises/04-joins.sql`

Add this beneath your existing exercise:

```sql
/*
Exercise 2: Preserving biopsy grain across PSA and treatment logic

Clinical requirement:
Return every prostate biopsy.

For each biopsy:
- Attach the most recent PSA within the prior 180 days.
- Add a flag indicating whether treatment occurred within
  90 days after the biopsy.
- Preserve biopsies with no PSA.
- Preserve biopsies with no treatment.

Output grain:
One row per prostate biopsy.

Anchor:
procedure_occurrence — qualifying prostate biopsy.

PSA relationship:
One biopsy may have zero or many eligible PSA measurements.

JOIN strategy:
LEFT JOIN measurement so biopsies without PSA remain.

PSA filters:
Place PSA concept and date filters in the ON clause.

PSA selection:
Rank eligible PSA measurements within each biopsy using ROW_NUMBER().
Order measurement_date descending so the most recent PSA receives rank 1.

Treatment:
Use CASE WHEN EXISTS because we only need a treatment indicator,
not the treatment rows themselves.

Missing PSA:
Leave PSA fields NULL.
Optionally create a separate has_prior_psa flag.

Validation:
Final row count should equal the number of distinct biopsy IDs.
*/


WITH biopsy_psa_candidates AS (

    SELECT
        po.person_id,
        po.procedure_occurrence_id,
        po.procedure_date,

        m.measurement_id,
        m.measurement_date,
        m.value_as_number,

        ROW_NUMBER() OVER (
            PARTITION BY po.procedure_occurrence_id
            ORDER BY
                m.measurement_date DESC,
                m.measurement_id DESC
        ) AS psa_rank

    FROM procedure_occurrence po

    LEFT JOIN measurement m
        ON m.person_id = po.person_id

        -- PSA concept filter
        AND m.measurement_concept_id = 3004410

        -- PSA must be within 180 days before the biopsy
        AND m.measurement_date
            BETWEEN DATE_SUB(po.procedure_date, 180)
                AND po.procedure_date

    WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'

)


SELECT
    b.person_id,
    b.procedure_occurrence_id,
    b.procedure_date,

    b.measurement_id,
    b.measurement_date,
    b.value_as_number,

    CASE
        WHEN b.measurement_id IS NOT NULL THEN 1
        ELSE 0
    END AS has_prior_psa,

    CASE
        WHEN EXISTS (

            SELECT 1
            FROM drug_exposure de

            WHERE de.person_id = b.person_id

              AND de.drug_exposure_start_date
                  BETWEEN b.procedure_date
                      AND DATE_ADD(b.procedure_date, 90)

              -- Add treatment concept filter here later

        )
        THEN 1
        ELSE 0
    END AS has_treatment_within_90_days

FROM biopsy_psa_candidates b

WHERE b.psa_rank = 1;

/*
Validation 1:
The final result should contain one row per biopsy.
*/

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT procedure_occurrence_id) AS distinct_biopsy_count
FROM final_result;

/*
Validation 2:
This query should return zero rows.
*/

SELECT
    procedure_occurrence_id,
    COUNT(*) AS rows_per_biopsy
FROM final_result
GROUP BY procedure_occurrence_id
HAVING COUNT(*) > 1;