/*
Module 4 — JOINs

Clinical requirement:
Return every prostate biopsy.

For each biopsy:
- Attach the most recent PSA within the prior 180 days.
- Add a flag indicating whether treatment occurred within 90 days after the biopsy.
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
Place the PSA concept and date filters in the ON clause.

PSA selection:
Use ROW_NUMBER() partitioned by procedure_occurrence_id.
Order measurement_date descending so the most recent PSA receives rank 1.

Treatment:
Use CASE WHEN EXISTS because only a treatment indicator is required.

Missing PSA:
Leave PSA fields NULL.

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
       AND m.measurement_concept_id = 3004410
       AND m.measurement_date
           BETWEEN DATE_SUB(po.procedure_date, 180)
               AND po.procedure_date

    WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'
),

final_result AS (

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
            )
            THEN 1
            ELSE 0
        END AS has_treatment_within_90_days

    FROM biopsy_psa_candidates b

    WHERE b.psa_rank = 1
)

SELECT *
FROM final_result;


/*
Validation 1:
Total rows should equal distinct biopsy IDs.
*/

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT procedure_occurrence_id) AS distinct_biopsy_count
FROM final_result;


/*
Validation 2:
This should return zero rows.
*/

SELECT
    procedure_occurrence_id,
    COUNT(*) AS rows_per_biopsy
FROM final_result
GROUP BY procedure_occurrence_id
HAVING COUNT(*) > 1;