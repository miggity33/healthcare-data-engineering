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