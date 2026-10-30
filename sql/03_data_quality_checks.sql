-- ============================================================================
-- Project 03: The Attrition Blindspot
-- 03_data_quality_checks.sql
-- Profiles hr.employees_raw before any modelling. Run each query separately
-- (highlight the query, press F5): pgAdmin only shows the last result of a
-- multi-statement run.
-- ============================================================================

-- 1. Row count and key uniqueness (expect 1470 / 1470)
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT employee_number) AS distinct_employees
FROM hr.employees_raw;

-- 2. Null scan across the analysis-critical columns (expect all zeros)
SELECT
    COUNT(*) FILTER (WHERE attrition IS NULL)                  AS null_attrition,
    COUNT(*) FILTER (WHERE performance_rating IS NULL)         AS null_performance,
    COUNT(*) FILTER (WHERE overtime IS NULL)                   AS null_overtime,
    COUNT(*) FILTER (WHERE years_since_last_promotion IS NULL) AS null_promotion,
    COUNT(*) FILTER (WHERE years_with_curr_manager IS NULL)    AS null_manager,
    COUNT(*) FILTER (WHERE monthly_income IS NULL)             AS null_income
FROM hr.employees_raw;

-- 3. Constant (zero-information) columns: each should return 1 distinct value
SELECT COUNT(DISTINCT employee_count) AS employee_count_values,
       COUNT(DISTINCT standard_hours) AS standard_hours_values,
       COUNT(DISTINCT over18)         AS over18_values
FROM hr.employees_raw;

-- 4. Category validation
SELECT attrition, COUNT(*) FROM hr.employees_raw GROUP BY 1 ORDER BY 1;
SELECT overtime,  COUNT(*) FROM hr.employees_raw GROUP BY 1 ORDER BY 1;
-- performance_rating contains only 3 and 4 (no 1s or 2s) in this dataset
SELECT performance_rating, COUNT(*) FROM hr.employees_raw GROUP BY 1 ORDER BY 1;

-- 5. Logical consistency of tenure fields (expect 0)
SELECT COUNT(*) AS bad_tenure_logic
FROM hr.employees_raw
WHERE years_in_current_role      > years_at_company
   OR years_since_last_promotion > years_at_company
   OR years_with_curr_manager    > years_at_company
   OR years_at_company           > total_working_years;

-- 6. Distributions that informed the thresholds
SELECT
    percentile_cont(ARRAY[0.25, 0.5, 0.75, 0.9]) WITHIN GROUP (ORDER BY years_since_last_promotion) AS promo_gap_percentiles,
    percentile_cont(ARRAY[0.25, 0.5, 0.75, 0.9]) WITHIN GROUP (ORDER BY years_with_curr_manager)    AS manager_tenure_percentiles
FROM hr.employees_raw;

-- 7. Baseline attrition (expect 237 leavers, 16.1%)
SELECT COUNT(*) FILTER (WHERE attrition = 'Yes') AS leavers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE attrition = 'Yes') / COUNT(*), 1) AS attrition_pct
FROM hr.employees_raw;
