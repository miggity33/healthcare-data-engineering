# Module 4 — JOINs

## Why this matters

A JOIN determines both:

1. Which rows survive
2. How the output grain changes

## Core questions

- What is the left-side grain?
- What is the right-side grain?
- What is the expected cardinality?
- Which unmatched rows should survive?
- Should right-table filters be in `ON` or `WHERE`?
- Would `EXISTS` preserve the grain better?

# Module 4 — JOINs

## Why this matters

A JOIN does two important things:

1. It determines which rows survive.
2. It can change the grain of the result.

The SQL syntax is simple. The engineering challenge is choosing the join pattern that matches the clinical question.

---

## Core questions before every JOIN

- What is the left-side grain?
- What is the right-side grain?
- What is the expected cardinality?
- Which unmatched rows should survive?
- Does the JOIN change the study population?
- Does the JOIN change the output grain?
- Should right-table filters go in `ON` or `WHERE`?
- Do I actually need rows from the right-side table?
- Would `EXISTS` preserve the grain better?

---

## INNER JOIN

An `INNER JOIN` keeps only rows that match on both sides.

```sql
SELECT
    p.person_id,
    co.condition_occurrence_id
FROM person p
INNER JOIN condition_occurrence co
    ON co.person_id = p.person_id;