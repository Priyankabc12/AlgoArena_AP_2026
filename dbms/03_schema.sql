CREATE TYPE "SubmissionStatus" AS ENUM (
  'PENDING', 'ACCEPTED', 'WRONG_ANSWER', 'TIME_LIMIT_EXCEEDED',
  'MEMORY_LIMIT_EXCEEDED', 'COMPILATION_ERROR', 'RUNTIME_ERROR', 'INTERNAL_ERROR'
);

CREATE TABLE "user" (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  "emailVerified" BOOLEAN NOT NULL DEFAULT FALSE,
  image TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "session" (
  id TEXT PRIMARY KEY,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  token TEXT NOT NULL UNIQUE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "ipAddress" TEXT,
  "userAgent" TEXT,
  "userId" TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "session_userId_idx" ON "session" ("userId");

CREATE TABLE "account" (
  id TEXT PRIMARY KEY,
  "accountId" TEXT NOT NULL,
  "providerId" TEXT NOT NULL,
  "userId" TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE ON UPDATE CASCADE,
  "accessToken" TEXT,
  "refreshToken" TEXT,
  "idToken" TEXT,
  "accessTokenExpiresAt" TIMESTAMP(3),
  "refreshTokenExpiresAt" TIMESTAMP(3),
  scope TEXT,
  password TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "account_userId_idx" ON "account" ("userId");

CREATE TABLE "verification" (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL,
  value TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "verification_identifier_idx" ON "verification" (identifier);

CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  statement TEXT NOT NULL,
  time_limit DOUBLE PRECISION NOT NULL DEFAULT 2,
  memory_limit INTEGER NOT NULL DEFAULT 128000,
  created_by_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP(3) NOT NULL
);

CREATE TABLE test_cases (
  id SERIAL PRIMARY KEY,
  question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE ON UPDATE CASCADE,
  stdin TEXT NOT NULL DEFAULT '',
  expected_output TEXT NOT NULL,
  is_sample BOOLEAN NOT NULL DEFAULT FALSE,
  position INTEGER NOT NULL,
  CONSTRAINT test_cases_question_id_position_key UNIQUE (question_id, position)
);

CREATE TABLE submissions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE ON UPDATE CASCADE,
  question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE ON UPDATE CASCADE,
  source_code TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'python',
  status "SubmissionStatus" NOT NULL DEFAULT 'PENDING',
  runtime_ms DOUBLE PRECISION,
  memory_kb INTEGER,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX submissions_user_id_question_id_created_at_idx
  ON submissions (user_id, question_id, created_at);

CREATE TABLE submission_case_results (
  id TEXT PRIMARY KEY,
  submission_id TEXT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE ON UPDATE CASCADE,
  test_case_id INTEGER REFERENCES test_cases(id) ON DELETE SET NULL ON UPDATE CASCADE,
  position INTEGER NOT NULL,
  is_sample BOOLEAN NOT NULL,
  stdin TEXT,
  expected_output TEXT,
  status "SubmissionStatus" NOT NULL,
  runtime_ms DOUBLE PRECISION,
  memory_kb INTEGER,
  actual_output TEXT,
  CONSTRAINT submission_case_results_submission_id_position_key UNIQUE (submission_id, position)
);
