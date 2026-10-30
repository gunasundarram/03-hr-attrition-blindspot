-- ============================================================================
-- Project 03: The Attrition Blindspot
-- 02_load_data.sql
-- Loads data/raw/ibm_hr_attrition_raw.csv into hr.employees_raw.
--
-- METHOD USED FOR THIS PROJECT (pgAdmin, no command line):
--   1. Expand Databases > hr_attrition > Schemas > hr > Tables
--   2. Right-click employees_raw > Import/Export Data...
--   3. Import | Filename = data/raw/ibm_hr_attrition_raw.csv
--      Format = csv | Header = ON | Delimiter = ,
--   4. Click OK, then run the verification query at the bottom of this file.
--
-- COMMAND-LINE ALTERNATIVE (psql only; \copy is a psql command, not SQL, so it
-- will NOT run in the pgAdmin Query Tool). Use forward slashes on Windows:
--
--   \copy hr.employees_raw FROM 'C:/Users/YOURNAME/Documents/03-hr-attrition-blindspot/data/raw/ibm_hr_attrition_raw.csv' WITH (FORMAT csv, HEADER true)
-- ============================================================================

-- Verification: expect 1470 rows and 1470 distinct employees
SELECT COUNT(*)                        AS total_rows,
       COUNT(DISTINCT employee_number) AS distinct_employees
FROM hr.employees_raw;
