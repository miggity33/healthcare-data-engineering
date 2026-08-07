/*
Module 5 — EXISTS and Set-Based Filtering

Clinical requirement:
Return every prostate biopsy for patients who had a prostate cancer
diagnosis on or before the biopsy date.

Exclude biopsies if the patient had ADT within 30 days before the biopsy.

Add a flag indicating whether the patient received ADT within 90 days
after the biopsy.

Output grain:
One row per prostate biopsy.

Anchor:
procedure_occurrence — qualifying prostate biopsy.

Diagnosis qualification:
Use EXISTS.

Diagnosis temporal rule:
condition_start_date must be on or before procedure_date.

Prior ADT exclusion:
Use NOT EXISTS.

Prior ADT temporal rule:
drug_exposure_start_date must fall between 30 days before the biopsy
and the biopsy date.

Post-biopsy ADT:
Use CASE WHEN EXISTS.

Post-biopsy ADT temporal rule:
drug_exposure_start_date must fall between the biopsy date
and 90 days after the biopsy.

Validation:
The final result should contain one row per procedure_occurrence_id.
*/

WITH final_result AS (

    SELECT
        po.person_id,
        po.procedure_occurrence_id,
        po.procedure_date,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM drug_exposure de_after
                WHERE de_after.person_id = po.person_id
                  AND de_after.drug_exposure_start_date
                      BETWEEN po.procedure_date
                          AND DATE_ADD(po.procedure_date, 90)

                  -- Add ADT concept filter here
            )
            THEN 1
            ELSE 0
        END AS has_adt_within_90_days

    FROM procedure_occurrence po

    WHERE po.procedure_source_value RLIKE '(?i)prostate.*biopsy'

      AND EXISTS (
          SELECT 1
          FROM condition_occurrence co
          WHERE co.person_id = po.person_id
            AND co.condition_start_date <= po.procedure_date

            -- Add prostate cancer concept filter here
      )

      AND NOT EXISTS (
          SELECT 1
          FROM drug_exposure de_before
          WHERE de_before.person_id = po.person_id
            AND de_before.drug_exposure_start_date
                BETWEEN DATE_SUB(po.procedure_date, 30)
                    AND po.procedure_date

            -- Add ADT concept filter here
      )
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