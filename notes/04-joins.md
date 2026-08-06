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