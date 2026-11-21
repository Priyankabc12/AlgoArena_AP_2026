# AP Query Timings

**Database:** PostgreSQL 17.10  
**Machine:** MacBook Pro (M4)  
**Method:** `EXPLAIN (ANALYZE, BUFFERS)`, three runs per query, arithmetic mean reported. All write queries ran inside `BEGIN … ROLLBACK`.

## Benchmark data

The existing schema was loaded into an isolated local database with deterministic representative data:

| Table | Rows |
|---|---:|
| user | 10,000 |
| account | 10,000 |
| session | 5,000 |
| verification | 1,000 |
| questions | 500 |
| test_cases | 5,000 |
| submissions | 50,000 |
| submission_case_results | 500,000 |

Read queries used existing representative records (for example `u42`, `question-42`, and `sub42`). Write queries used valid values and were rolled back after every run. Raw plans for all three runs are stored in `dbms/plans/`.

## Timing results

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|---|---|---|---:|---:|---:|---:|---|
| R1 | READ | Resolve an active session and its user by token | 0.029 | 0.022 | 0.021 | 0.024 | Index Scan |
| R2 | READ | Find a user by normalized email | 0.021 | 0.087 | 0.177 | 0.095 | Index Scan |
| R3 | READ | Load a credential account and its user | 0.028 | 0.039 | 0.029 | 0.032 | Seq Scan + Index Scan |
| R4 | READ | Load one question with ordered test cases | 0.357 | 0.097 | 0.057 | 0.170 | Index Scan + Bitmap Heap Scan |
| R5 | READ | Load a question with sample test cases | 0.117 | 0.068 | 0.081 | 0.089 | Index Scan + Bitmap Heap Scan |
| R6 | READ | Load a question with all test cases | 0.062 | 0.062 | 0.065 | 0.063 | Index Scan + Bitmap Heap Scan |
| R7 | READ | List one user's paginated submission history | 0.272 | 0.200 | 0.095 | 0.189 | Bitmap Heap Scan + Seq Scan |
| R8 | READ | Count one user's submissions for pagination | 0.262 | 0.112 | 0.115 | 0.163 | Index Only Scan + Seq Scan |
| R9 | READ | Load an owned submission and case-result snapshots | 0.126 | 0.083 | 0.105 | 0.105 | Index Scan + Bitmap Heap Scan |
| W1 | WRITE | Create a user | 0.609 | 0.192 | 0.126 | 0.309 | Insert (no scan) |
| W2 | WRITE | Create a credential account | 0.522 | 0.381 | 0.338 | 0.414 | Insert (no scan) |
| W3 | WRITE | Create a signed-in session | 0.457 | 0.514 | 0.378 | 0.450 | Insert (no scan) |
| W4 | WRITE | Refresh session metadata and expiry | 0.292 | 0.160 | 0.134 | 0.195 | Index Scan |
| W5 | WRITE | Delete a session during sign-out | 0.075 | 0.066 | 0.075 | 0.072 | Index Scan |
| W6 | WRITE | Promote a user to administrator | 0.131 | 0.137 | 0.122 | 0.130 | Index Scan |
| W7 | WRITE | Create a question | 0.342 | 0.326 | 0.410 | 0.359 | Insert (no scan) |
| W8 | WRITE | Insert a question's test cases from JSON | 0.787 | 0.340 | 0.366 | 0.498 | Insert (no table scan) |
| W9 | WRITE | Create a pending submission | 0.523 | 0.484 | 0.411 | 0.473 | Insert (no scan) |
| W10 | WRITE | Save a submission's aggregate result | 0.167 | 0.136 | 0.150 | 0.151 | Index Scan |
| W11 | WRITE | Save per-case result snapshots from JSON | 0.516 | 0.423 | 0.419 | 0.453 | Insert (no table scan) |
| W12 | WRITE | Mark a failed submission as internal error | 0.116 | 0.108 | 0.121 | 0.115 | Index Scan |

## Plan observations

- R1, R2, R4–R6, and R9 use primary-key, unique, or foreign-key-supporting indexes and complete well below 1 ms.
- R3 performs a sequential scan of `account` because the schema has no composite index on `("accountId", "providerId")`. At 10,000 rows it is still fast, but that index should be considered if authentication volume grows.
- R7 and R8 use `submissions_user_id_question_id_created_at_idx` to restrict submissions by user. PostgreSQL sequentially scans the small 500-row `questions` table, which is cheaper than forcing another access path.
- Every measured average is derived from the three `Execution Time` values in its corresponding raw plan file.
