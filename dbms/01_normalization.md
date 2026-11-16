# Database Normalization — AlgoArena

## About the database

AlgoArena is an online coding platform where users can create questions, add test cases and submit their solutions. Each submission is checked against multiple test cases and the result of every case is stored separately. The database also contains the tables required for user authentication such as sessions, accounts and verification records.

The main goal of normalization is to avoid duplicate data and make sure that every value is stored in the correct table. We have taken the database through 1NF, 2NF and 3NF. We have also checked BCNF wherever possible.

## Unnormalized form (UNF)

If the main application data was stored as one simplified combined record, it would look similar to this:

```text
ALGO_ARENA_DATA(
    user_id, user_name, user_email, role,
    sessions { session_id, token, expires_at, ip_address },
    accounts { account_id, provider_id, password, access_token },
    questions {
        question_id, slug, title, statement, time_limit, memory_limit,
        test_cases { test_case_id, stdin, expected_output, is_sample, position },
        submissions {
            submission_id, source_code, language, status, runtime_ms, memory_kb,
            case_results {
                result_id, test_case_id, position, status,
                runtime_ms, memory_kb, actual_output
            }
        }
    }
)
```

This is not normalized because sessions, accounts, questions, test cases, submissions and case results are repeating groups. User and question details would also be repeated many times.

## First Normal Form (1NF)

A table is in 1NF when:

- every column contains one atomic value;
- there are no repeating groups or arrays inside a row;
- every row can be uniquely identified.

To achieve 1NF, we separated each repeating group into its own table:

| Table | Primary key | Purpose |
|---|---|---|
| `User` | `id` | Stores one row for each user. |
| `Session` | `id` | Stores individual login sessions. |
| `Account` | `id` | Stores individual authentication-provider accounts. |
| `Verification` | `id` | Stores individual verification records. |
| `Question` | `id` | Stores one coding question per row. |
| `TestCase` | `id` | Stores one test case per row. |
| `Submission` | `id` | Stores one submitted solution per row. |
| `SubmissionCaseResult` | `id` | Stores the result of one test case for one submission. |

For example, a question with ten test cases does not store ten inputs inside the `Question` row. It has ten separate rows in `TestCase`, connected using `questionId`.

All fields such as `title`, `language`, `status`, `runtimeMs` and `position` contain single values. Therefore, the final tables satisfy 1NF.

## Second Normal Form (2NF)

A table is in 2NF when it is already in 1NF and every non-prime attribute depends on the complete value of every candidate key. Partial dependency normally happens when a table has a composite candidate key.

Most tables in this schema use a single-column primary key, so partial dependency cannot occur in those tables. Two tables also have composite candidate keys created using `@@unique`:

### `TestCase`

The primary key is `id`, and `(questionId, position)` is also a candidate key.

```text
id → questionId, stdin, expectedOutput, isSample, position
(questionId, position) → id, stdin, expectedOutput, isSample
```

`questionId` alone cannot identify a test case because one question can have many test cases. `position` alone also cannot identify it because different questions can use the same position. The remaining attributes depend on the complete pair.

### `SubmissionCaseResult`

The primary key is `id`, and `(submissionId, position)` is also a candidate key.

```text
id → submissionId, testCaseId, position, isSample, stdin,
     expectedOutput, status, runtimeMs, memoryKb, actualOutput

(submissionId, position) → id, testCaseId, isSample, stdin,
                           expectedOutput, status, runtimeMs,
                           memoryKb, actualOutput
```

`submissionId` alone identifies a submission but not one particular case result. `position` is only meaningful inside that submission. Therefore, the result attributes depend on the full candidate key.

Since no table contains a partial dependency, the schema satisfies 2NF.

## Third Normal Form (3NF)

A table is in 3NF when it is already in 2NF and there is no transitive dependency. This means a non-key column should not depend on another non-key column.

We avoided transitive dependencies by keeping different types of information in separate tables:

- User details such as `name`, `email` and `role` are stored only in `User`.
- `Question` stores `createdById` instead of copying the creator's name and email.
- `TestCase` stores `questionId` instead of copying the question title and statement.
- `Submission` stores `userId` and `questionId` instead of copying user and question details.
- `SubmissionCaseResult` stores `submissionId` instead of copying the submission's source code, language or user.
- `Session` and `Account` store `userId` instead of repeating user information.

For example:

```text
submissionId → userId
userId → user name and email
```

The user name and email are not stored in `Submission`. They are obtained through the `User` relation. Because of this, there is no transitive dependency inside the `Submission` table.

The same method is followed for questions, test cases, sessions and accounts. Therefore, the schema satisfies 3NF.

## Functional dependencies in the final schema

### `User`

Candidate keys: `id`, `email`

```text
id → name, email, emailVerified, image, role, createdAt, updatedAt
email → id, name, emailVerified, image, role, createdAt, updatedAt
```

### `Session`

Candidate keys: `id`, `token`

```text
id → expiresAt, token, createdAt, updatedAt, ipAddress, userAgent, userId
token → id, expiresAt, createdAt, updatedAt, ipAddress, userAgent, userId
```

### `Account`

Candidate key: `id`

```text
id → accountId, providerId, userId, accessToken, refreshToken, idToken,
     accessTokenExpiresAt, refreshTokenExpiresAt, scope, password,
     createdAt, updatedAt
```

### `Verification`

Candidate key: `id`

```text
id → identifier, value, expiresAt, createdAt, updatedAt
```

The index on `identifier` is not unique, so `identifier` is not treated as a candidate key.

### `Question`

Candidate keys: `id`, `slug`

```text
id → slug, title, statement, timeLimit, memoryLimit,
     createdById, createdAt, updatedAt

slug → id, title, statement, timeLimit, memoryLimit,
       createdById, createdAt, updatedAt
```

### `TestCase`

Candidate keys: `id`, (`questionId`, `position`)

```text
id → questionId, stdin, expectedOutput, isSample, position
(questionId, position) → id, stdin, expectedOutput, isSample
```

### `Submission`

Candidate key: `id`

```text
id → userId, questionId, sourceCode, language, status,
     runtimeMs, memoryKb, createdAt
```

The index on (`userId`, `questionId`, `createdAt`) is not unique, so it is not a candidate key.

### `SubmissionCaseResult`

Candidate keys: `id`, (`submissionId`, `position`)

```text
id → submissionId, testCaseId, position, isSample, stdin,
     expectedOutput, status, runtimeMs, memoryKb, actualOutput

(submissionId, position) → id, testCaseId, isSample, stdin,
                           expectedOutput, status, runtimeMs,
                           memoryKb, actualOutput
```

## Why test-case data is also present in `SubmissionCaseResult`

`SubmissionCaseResult` contains `position`, `isSample`, `stdin` and `expectedOutput`, even though it can also reference `TestCase`. For this normalization, we are treating these fields as a snapshot of the test case at the time the submission was judged.

This is useful because `testCaseId` is nullable and uses `ON DELETE SET NULL`. If a test case is later changed or deleted, the old submission result can still show its original position, sample flag, input and expected output. Therefore, these values describe that particular submission result and are not treated as current `TestCase` data.

The application must copy these four values when it judges the submission. The Prisma schema allows this snapshot design, but it does not by itself guarantee that the copied values match the test case at judging time.

If these fields were always required to match the current `TestCase` row, they would be unnecessary duplicate data and should be removed. In this schema they are kept intentionally for submission history.

## BCNF check

A relation is in BCNF when every determinant is a candidate key.

| Table | Determinants | Result |
|---|---|---|
| `User` | `id`, `email` | BCNF |
| `Session` | `id`, `token` | BCNF |
| `Account` | `id` | BCNF |
| `Verification` | `id` | BCNF |
| `Question` | `id`, `slug` | BCNF |
| `TestCase` | `id`, (`questionId`, `position`) | BCNF |
| `Submission` | `id` | BCNF |
| `SubmissionCaseResult` | `id`, (`submissionId`, `position`) | BCNF when its copied test-case fields are treated as submission-time snapshots. |

Under the functional dependencies listed above, every determinant is a candidate key. Because of this, the final schema is in 3NF and its relations also satisfy BCNF when the case-result fields are used as submission-time snapshots.

## Final normalized relations

```text
User(id, name, email, emailVerified, image, role, createdAt, updatedAt)

Session(id, expiresAt, token, createdAt, updatedAt,
        ipAddress, userAgent, userId)

Account(id, accountId, providerId, userId, accessToken, refreshToken,
        idToken, accessTokenExpiresAt, refreshTokenExpiresAt,
        scope, password, createdAt, updatedAt)

Verification(id, identifier, value, expiresAt, createdAt, updatedAt)

Question(id, slug, title, statement, timeLimit, memoryLimit,
         createdById, createdAt, updatedAt)

TestCase(id, questionId, stdin, expectedOutput, isSample, position)

Submission(id, userId, questionId, sourceCode, language,
           status, runtimeMs, memoryKb, createdAt)

SubmissionCaseResult(id, submissionId, testCaseId, position, isSample,
                     stdin, expectedOutput, status, runtimeMs,
                     memoryKb, actualOutput)
```

## Conclusion

We separated users, authentication data, questions, test cases, submissions and individual case results into different relations. Repeating groups were removed in 1NF, partial dependencies were checked in 2NF and transitive dependencies were removed in 3NF. The declared functional dependencies also satisfy BCNF. This structure avoids unnecessary duplication while keeping the submission history required by AlgoArena.
