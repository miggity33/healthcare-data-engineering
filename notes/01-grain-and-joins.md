# Lesson 1: Grain and Join Cardinality

## Grain

Grain describes what one row represents.

Examples:

- `person`: one row per patient
- `condition_occurrence`: one row per diagnosis event
- `procedure_occurrence`: one row per procedure event
- pathology report table: one row per report, case, specimen, or order depending on the source design

## Core rule

Before writing SQL, finish this sentence:

> My final result should contain one row per ______.

## Join multiplication

If one patient has:

- 2 condition rows
- 3 procedure rows
- 2 pathology rows

A person-level join may create:

2 × 3 × 2 = 12 rows

## Person-level versus event-level linkage

Person-level linkage:

```sql
po.person_id = pr.person_id