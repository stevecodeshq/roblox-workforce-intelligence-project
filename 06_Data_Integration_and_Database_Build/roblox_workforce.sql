-- =====================================================================
--  roblox_workforce.sql
--  Database build script
--
--  Workforce Intelligence and Organizational Performance Analysis
--  Roblox Africa Operations (Ghana Hub)
--
--  Stage 6 - Data Integration and Database Build
--  Version 1.0  -  1 August 2026
--
--  Written for SQLite. Notes at the foot of the file explain the three
--  changes needed for MySQL or PostgreSQL.
--
--  WHAT THIS SCRIPT DOES
--    1. Creates seven tables with correct data types and keys
--    2. Leaves the tables empty, ready for the cleaned data to be loaded
--    3. Creates indexes so joins are fast
--    4. Creates one view, master_employee, which is the integrated dataset
--    5. Provides verification queries that must all pass before Stage 7
--
--  WHAT IT DOES NOT DO
--    It does not load the data. Loading is done by the Python script in
--    section 9, because the cleaned data lives in .xlsx files.
--
--  THE RULE THAT MATTERS MOST
--    The five person-level tables are joined into master_employee.
--    The two performance tables are NOT joined into it. They hold one row
--    per employee per year, so merging them would repeat every salary five
--    times and overstate total cost fivefold.
-- =====================================================================


-- =====================================================================
--  SECTION 1 - CREATE THE DATABASE
-- =====================================================================
-- SQLite creates the database simply by opening a file:
--     sqlite3 roblox_workforce.db
--
-- MySQL / PostgreSQL equivalent:
--     CREATE DATABASE roblox_workforce;
--     USE roblox_workforce;              -- MySQL
--     \c roblox_workforce                -- PostgreSQL

PRAGMA foreign_keys = ON;   -- SQLite does not enforce foreign keys unless asked


-- =====================================================================
--  SECTION 2 - REMOVE ANY PREVIOUS BUILD
--  Dropped children first, parents last, or the foreign keys block it.
-- =====================================================================
DROP VIEW  IF EXISTS master_employee;
DROP TABLE IF EXISTS employee_performance;
DROP TABLE IF EXISTS department_performance;
DROP TABLE IF EXISTS education;
DROP TABLE IF EXISTS finance;
DROP TABLE IF EXISTS health;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS department;


-- =====================================================================
--  SECTION 3 - LOOKUP TABLE
--  department must exist before employee, because employee points at it.
-- =====================================================================
CREATE TABLE department (
    department_code   VARCHAR(3)   NOT NULL,
    department_name   VARCHAR(50)  NOT NULL,

    CONSTRAINT pk_department      PRIMARY KEY (department_code),
    CONSTRAINT uq_department_name UNIQUE (department_name)
);
-- department_name is UNIQUE because department_performance joins on the
-- NAME rather than the code. Without this constraint that join could
-- silently multiply rows.


-- =====================================================================
--  SECTION 4 - THE CENTRAL TABLE
--  One row per employee. Everything else points here.
-- =====================================================================
CREATE TABLE employee (
    employee_id       INTEGER      NOT NULL,
    other_names       VARCHAR(40)  NOT NULL,
    last_name         VARCHAR(20)  NOT NULL,
    age               INTEGER      NOT NULL,
    position          VARCHAR(20)  NOT NULL,
    date_joined       DATE         NOT NULL,
    phone_number      VARCHAR(15)  NOT NULL,   -- TEXT, not a number: it is a
                                               -- label, never an amount, and a
                                               -- numeric type drops leading digits
    gender            VARCHAR(10)  NOT NULL,
    employee_status   VARCHAR(15)  NOT NULL,
    department_code   VARCHAR(3),              -- nullable by design: see note below
    email_address     VARCHAR(80)  NOT NULL,

    CONSTRAINT pk_employee     PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_dept FOREIGN KEY (department_code)
        REFERENCES department (department_code),

    -- these three rules make the errors found in Stage 3 impossible to reintroduce
    CONSTRAINT ck_employee_age    CHECK (age BETWEEN 18 AND 65),
    CONSTRAINT ck_employee_gender CHECK (gender IN ('Male', 'Female')),
    CONSTRAINT ck_employee_status CHECK (employee_status IN ('Active', 'Inactive', 'On Leave'))
);
-- department_code is left nullable so that a future employee awaiting
-- assignment can still be recorded. Every row in the current cleaned data
-- has a value, which verification query V6 confirms.


-- =====================================================================
--  SECTION 5 - THE THREE ONE-TO-ONE TABLES
--  Exactly one row per employee. These are safe to merge.
-- =====================================================================

CREATE TABLE education (
    employee_id           INTEGER      NOT NULL,
    institution_country   VARCHAR(30)  NOT NULL,
    education_level       VARCHAR(30)  NOT NULL,
    institution_name      VARCHAR(80)  NOT NULL,
    degree_title          VARCHAR(10)  NOT NULL,
    field_of_study        VARCHAR(40)  NOT NULL,
    graduation_date       DATE         NOT NULL,

    CONSTRAINT pk_education PRIMARY KEY (employee_id),
    CONSTRAINT fk_education_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
);
-- employee_id is both the primary key and the foreign key. That is what
-- enforces one-to-one: a second education row for the same person is
-- rejected by the database rather than quietly duplicating them later.
-- The raw file's Education Record_id column was dropped during cleaning
-- because it repeated employee_id in all 30,000 rows.


CREATE TABLE finance (
    finance_id       VARCHAR(15)    NOT NULL,
    employee_id      INTEGER        NOT NULL,
    basic_salary     DECIMAL(12,2)  NOT NULL,
    allowances       DECIMAL(12,2)  NOT NULL,
    tax_id           VARCHAR(20)    NOT NULL,   -- sensitive
    account_number   VARCHAR(20)    NOT NULL,   -- sensitive; TEXT because
                                                -- lengths vary 5-13 digits
    bank_name        VARCHAR(40)    NOT NULL,

    CONSTRAINT pk_finance PRIMARY KEY (finance_id),
    CONSTRAINT uq_finance_employee UNIQUE (employee_id),
    CONSTRAINT fk_finance_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
);
-- Money is DECIMAL, never FLOAT. Floating point cannot represent decimal
-- fractions exactly, so totals drift by fractions of a cent over 30,000 rows.
--
-- WARNING: the period of basic_salary and allowances is not stated in the
-- source data (open question O1). Currency is USD, confirmed by the client.
-- Do not annualise or divide these figures until the client answers.


CREATE TABLE health (
    health_id               VARCHAR(15)  NOT NULL,
    employee_id             INTEGER      NOT NULL,
    created_at              TIMESTAMP    NOT NULL,
    updated_at              TIMESTAMP    NOT NULL,
    medical_leave_eligible  VARCHAR(5)   NOT NULL,
    insurance_status        VARCHAR(15)  NOT NULL,
    insurance_provider      VARCHAR(40)  NOT NULL,
    policy_number           VARCHAR(20)  NOT NULL,   -- sensitive
    insurance_plan_type     VARCHAR(15)  NOT NULL,
    medical_leave_balance   INTEGER      NOT NULL,

    CONSTRAINT pk_health PRIMARY KEY (health_id),
    CONSTRAINT uq_health_employee UNIQUE (employee_id),
    CONSTRAINT fk_health_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id),
    CONSTRAINT ck_health_status CHECK (insurance_status IN ('Active', 'Expired', 'Pending')),
    CONSTRAINT ck_health_balance CHECK (medical_leave_balance BETWEEN 0 AND 30)
);
-- Administrative insurance and leave data only. It contains nothing clinical,
-- so no medical or diagnostic conclusion may be drawn from it.


-- =====================================================================
--  SECTION 6 - THE TWO FACT TABLES
--  Many rows per employee or per department. These must NOT be merged.
-- =====================================================================

CREATE TABLE employee_performance (
    employee_id        INTEGER        NOT NULL,
    year               INTEGER        NOT NULL,
    performance_score  DECIMAL(4,2)   NOT NULL,
    projects_completed INTEGER        NOT NULL,
    training_hours     INTEGER        NOT NULL,
    attendance_rate    DECIMAL(5,2)   NOT NULL,   -- out of 100, not a fraction
    bonus_awarded      VARCHAR(5)     NOT NULL,

    CONSTRAINT pk_employee_performance PRIMARY KEY (employee_id, year),
    CONSTRAINT fk_perf_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id),
    CONSTRAINT ck_perf_year CHECK (year BETWEEN 2021 AND 2025)
);
-- The primary key is the PAIR of columns. Neither alone is unique: an
-- employee appears five times, and a year appears 30,000 times. Together
-- they identify exactly one row.
--
-- 150,000 rows = 30,000 employees x 5 years.


CREATE TABLE department_performance (
    department_name           VARCHAR(50)    NOT NULL,
    year                      INTEGER        NOT NULL,
    average_performance_score DECIMAL(4,2)   NOT NULL,
    total_revenue_generated   DECIMAL(14,2)  NOT NULL,
    total_cost                DECIMAL(14,2)  NOT NULL,
    training_hours_completed  INTEGER        NOT NULL,

    CONSTRAINT pk_department_performance PRIMARY KEY (department_name, year),
    CONSTRAINT fk_deptperf_department FOREIGN KEY (department_name)
        REFERENCES department (department_name),
    CONSTRAINT ck_deptperf_year CHECK (year BETWEEN 2021 AND 2025)
);
-- NOTE: the raw file's DepartmentId column is deliberately NOT loaded.
-- It ran 1 to 40 and looked like a department key, but there are only
-- 8 departments - it was a row counter (8 departments x 5 years). Joining
-- on it would attach the wrong department to 32 of the 40 rows, and nothing
-- would appear broken. This table joins on the department NAME instead.
--
-- WARNING: total_cost does not reconcile with the finance table. Summed
-- salary plus allowances is roughly 21 times this figure, so the two are on
-- different scales (open question O2). Never divide one by the other.


-- =====================================================================
--  SECTION 7 - INDEXES
--  Primary keys are indexed automatically. These cover the columns that
--  filters and groupings actually use.
-- =====================================================================
CREATE INDEX idx_employee_dept     ON employee (department_code);
CREATE INDEX idx_employee_status   ON employee (employee_status);
CREATE INDEX idx_employee_gender   ON employee (gender);
CREATE INDEX idx_education_field   ON education (field_of_study);
CREATE INDEX idx_health_status     ON health (insurance_status);
CREATE INDEX idx_perf_year         ON employee_performance (year);
CREATE INDEX idx_deptperf_year     ON department_performance (year);


-- =====================================================================
--  SECTION 8 - THE INTEGRATED DATASET
--
--  This view is the "integrated analytical dataset" named in the brief.
--
--  It joins the five person-level tables and NOTHING ELSE. Every join is a
--  LEFT JOIN from employee, so the row count cannot fall below 30,000, and
--  every joined table is one-to-one, so it cannot rise above 30,000 either.
-- =====================================================================
CREATE VIEW master_employee AS
SELECT
    e.employee_id,
    e.other_names,
    e.last_name,
    e.age,
    CASE
        WHEN e.age <  25 THEN 'Under 25'
        WHEN e.age <  35 THEN '25-34'
        WHEN e.age <  45 THEN '35-44'
        WHEN e.age <  55 THEN '45-54'
        ELSE '55 and over'
    END                                    AS age_band,
    e.gender,
    e.position,
    e.employee_status,
    e.date_joined,
    e.department_code,
    d.department_name,

    ed.education_level,
    ed.field_of_study,
    ed.degree_title,
    ed.institution_name,
    ed.institution_country,
    ed.graduation_date,

    f.basic_salary,
    f.allowances,
    f.basic_salary + f.allowances           AS total_compensation,
    f.bank_name,

    h.insurance_status,
    h.insurance_plan_type,
    h.insurance_provider,
    h.medical_leave_eligible,
    h.medical_leave_balance
    -- tax_id, account_number, policy_number, phone_number and email_address
    -- are deliberately excluded: personally identifying or financial detail
    -- that must not reach a shared dashboard.

FROM       employee   e
LEFT JOIN  department d  ON e.department_code = d.department_code
LEFT JOIN  education  ed ON e.employee_id     = ed.employee_id
LEFT JOIN  finance    f  ON e.employee_id     = f.employee_id
LEFT JOIN  health     h  ON e.employee_id     = h.employee_id;
-- employee_performance and department_performance are NOT joined here.
-- Section 10 shows how to use them correctly.


-- =====================================================================
--  SECTION 9 - LOADING THE CLEANED DATA
--
--  The cleaned data is in .xlsx files, so it is loaded with Python rather
--  than pure SQL. Run this after the script above has created the tables.
--
--  import pandas as pd, sqlite3
--
--  con = sqlite3.connect("roblox_workforce.db")
--  con.execute("PRAGMA foreign_keys = ON")
--  P = "../04_Clean_Data"
--
--  # parents first, children after - foreign keys are enforced
--  ORDER = [
--    ("Department_clean.xlsx", "department",
--       {"department_code":"department_code", "department_name":"department_name"}),
--    ("employee_dataset_clean.xlsx", "employee",
--       {"EmployeeID":"employee_id", "Other Names":"other_names",
--        "Last Name":"last_name", "Age":"age", "Position":"position",
--        "Date Joined":"date_joined", "Phone Number":"phone_number",
--        "Gender":"gender", "employee_status":"employee_status",
--        "Department Code":"department_code", "Email Address":"email_address"}),
--    ("Education_clean.xlsx", "education",
--       {"employee_id":"employee_id", "Institution Country":"institution_country",
--        "Education Level":"education_level", "institution Name":"institution_name",
--        "Degree Title":"degree_title", "Field of Study":"field_of_study",
--        "Graduation Date":"graduation_date"}),
--    ("finance_dataset_clean.xlsx", "finance",
--       {"FinanceID":"finance_id", "StaffID":"employee_id",
--        "Basic Salary":"basic_salary", "Allowances":"allowances",
--        "TaxID":"tax_id", "Account Number":"account_number",
--        "Bank Name":"bank_name"}),
--    ("health_dataset_clean.xlsx", "health",
--       {"Health Id":"health_id", "Employee ID":"employee_id",
--        "created_at":"created_at", "updated_at":"updated_at",
--        "Medical_leave_eligible":"medical_leave_eligible",
--        "Insurance_status":"insurance_status",
--        "Insurance_provider":"insurance_provider",
--        "Policy_number":"policy_number",
--        "Insurance_plan_type":"insurance_plan_type",
--        "Medical_leave_balance":"medical_leave_balance"}),
--    ("employee_performance_clean.xlsx", "employee_performance",
--       {"EmployeeID":"employee_id", "Year":"year",
--        "Performance_Score":"performance_score",
--        "Projects_Completed":"projects_completed",
--        "Training_Hours":"training_hours",
--        "Attendance_Rate (%)":"attendance_rate",
--        "Bonus_Awarded":"bonus_awarded"}),
--    ("department_performance_clean.xlsx", "department_performance",
--       {"Department":"department_name", "Year":"year",
--        "Average_Performance_Score":"average_performance_score",
--        "Total_Revenue_Generated":"total_revenue_generated",
--        "Total_Cost":"total_cost",
--        "Training_Hours_Completed":"training_hours_completed"}),
--  ]
--
--  for filename, table, mapping in ORDER:
--      df = pd.read_excel(f"{P}/{filename}")
--      df = df[list(mapping)].rename(columns=mapping)   # drops DepartmentId
--      df.to_sql(table, con, if_exists="append", index=False)
--      print(f"{table:<24} {len(df):>7,} rows")
--
--  con.commit()
-- =====================================================================


-- =====================================================================
--  SECTION 10 - VERIFICATION
--  Run every query. If any answer differs from the expected value, stop.
-- =====================================================================

-- V1  Row counts.  Expected: 30000, 8, 30000, 30000, 30000, 150000, 40
SELECT 'employee'               AS table_name, COUNT(*) AS rows FROM employee
UNION ALL SELECT 'department',              COUNT(*) FROM department
UNION ALL SELECT 'education',               COUNT(*) FROM education
UNION ALL SELECT 'finance',                 COUNT(*) FROM finance
UNION ALL SELECT 'health',                  COUNT(*) FROM health
UNION ALL SELECT 'employee_performance',    COUNT(*) FROM employee_performance
UNION ALL SELECT 'department_performance',  COUNT(*) FROM department_performance;

-- V2  THE CRITICAL TEST. The integrated dataset must be exactly 30,000 rows.
--     More than that means a join is duplicating. Stop and find which.
SELECT COUNT(*) AS master_employee_rows FROM master_employee;

-- V3  No employee lost their joined data.  Expected: 0 in every column.
SELECT
    SUM(CASE WHEN department_name  IS NULL THEN 1 ELSE 0 END) AS missing_department,
    SUM(CASE WHEN education_level  IS NULL THEN 1 ELSE 0 END) AS missing_education,
    SUM(CASE WHEN basic_salary     IS NULL THEN 1 ELSE 0 END) AS missing_finance,
    SUM(CASE WHEN insurance_status IS NULL THEN 1 ELSE 0 END) AS missing_health
FROM master_employee;

-- V4  Every employee has exactly 5 performance years.  Expected: 5 and 5.
SELECT MIN(n) AS fewest_years, MAX(n) AS most_years
FROM (SELECT employee_id, COUNT(*) AS n FROM employee_performance GROUP BY employee_id);

-- V5  Every department has exactly 5 years.  Expected: 8 departments, 5 and 5.
SELECT COUNT(DISTINCT department_name) AS departments,
       MIN(n) AS fewest_years, MAX(n) AS most_years
FROM (SELECT department_name, COUNT(*) AS n FROM department_performance GROUP BY department_name);

-- V6  Data quality rules hold.  Expected: 0, 0, 22, 60.
SELECT
    SUM(CASE WHEN department_code IS NULL THEN 1 ELSE 0 END) AS null_department_code,
    SUM(CASE WHEN gender NOT IN ('Male','Female') THEN 1 ELSE 0 END) AS bad_gender,
    MIN(age) AS youngest,
    MAX(age) AS oldest
FROM employee;

-- V7  Totals match the cleaned files.  Expected: 262953103 and 49546519.
SELECT SUM(basic_salary) AS total_basic_salary,
       SUM(allowances)   AS total_allowances
FROM finance;


-- =====================================================================
--  SECTION 11 - HOW TO USE THE PERFORMANCE TABLES CORRECTLY
--  These are examples, not part of the build. They belong in Stage 7.
-- =====================================================================

-- CORRECT: aggregate performance to one row per employee, THEN join.
-- The subquery collapses 5 rows to 1 before the join, so nothing multiplies.
--
--   SELECT m.department_name,
--          COUNT(*)                     AS headcount,
--          ROUND(AVG(p.avg_score), 2)   AS avg_performance
--   FROM master_employee m
--   JOIN (SELECT employee_id, AVG(performance_score) AS avg_score
--         FROM employee_performance
--         GROUP BY employee_id) p
--     ON m.employee_id = p.employee_id
--   GROUP BY m.department_name;

-- WRONG: joining employee_performance directly to master_employee.
-- The result is 150,000 rows and every salary counted five times.
--
--   SELECT SUM(m.total_compensation)          -- five times too big
--   FROM master_employee m
--   JOIN employee_performance p ON m.employee_id = p.employee_id;

-- ALSO WRONG: attaching department_performance to employee rows.
-- Row count stays at 30,000, so the usual check does not catch it, but each
-- department's revenue is repeated once per employee - roughly 3,700 times.
--
--   SELECT SUM(dp.total_revenue_generated)    -- thousands of times too big
--   FROM master_employee m
--   JOIN department_performance dp ON m.department_name = dp.department_name;

-- CORRECT: keep department figures at department grain, and join headcount
-- to them rather than the other way round.
--
--   SELECT dp.department_name, dp.year,
--          dp.total_revenue_generated,
--          hc.headcount,
--          ROUND(dp.total_revenue_generated / hc.headcount, 2) AS revenue_per_head
--   FROM department_performance dp
--   JOIN (SELECT department_name, COUNT(*) AS headcount
--         FROM master_employee GROUP BY department_name) hc
--     ON dp.department_name = hc.department_name
--   WHERE dp.year = 2025;


-- =====================================================================
--  SECTION 12 - PORTING TO MySQL OR PostgreSQL
--
--  1. Add at the top:
--         CREATE DATABASE roblox_workforce;
--         USE roblox_workforce;            -- MySQL
--         \c roblox_workforce              -- PostgreSQL
--     and delete the PRAGMA line, which is SQLite only.
--
--  2. Data types:
--         MySQL       INTEGER -> INT, TIMESTAMP -> DATETIME
--         PostgreSQL  no changes needed; VARCHAR and DECIMAL are standard
--
--  3. Loading: replace the sqlite3 connection in section 9 with SQLAlchemy:
--         from sqlalchemy import create_engine
--         con = create_engine("mysql+pymysql://user:pass@localhost/roblox_workforce")
--         con = create_engine("postgresql://user:pass@localhost/roblox_workforce")
--     The pandas .to_sql() calls are otherwise identical.
--
--  Foreign keys, CHECK constraints and the view work unchanged in all three.
--  Note that MySQL versions before 8.0.16 parse CHECK constraints but ignore
--  them, so validate the data before loading if you are on an older release.
-- =====================================================================
