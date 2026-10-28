-- 1. Row count and key uniqueness
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT employee_number) AS distinct_employees
FROM hr.employees_raw;

-- 2. Null scan across the analysis-critical columns
SELECT
    COUNT(*) FILTER (WHERE attrition IS NULL)               AS null_attrition,
    COUNT(*) FILTER (WHERE performance_rating IS NULL)      AS null_perf,
    COUNT(*) FILTER (WHERE overtime IS NULL)                AS null_overtime,
    COUNT(*) FILTER (WHERE years_since_last_promotion IS NULL) AS null_promo,
    COUNT(*) FILTER (WHERE years_with_curr_manager IS NULL) AS null_mgr,
    COUNT(*) FILTER (WHERE monthly_income IS NULL)          AS null_income
FROM hr.employees_raw;

-- 3. Constant (zero-information) columns: candidates to drop
SELECT COUNT(DISTINCT employee_count) AS employee_count_vals,
       COUNT(DISTINCT standard_hours) AS standard_hours_vals,
       COUNT(DISTINCT over18)         AS over18_vals
FROM hr.employees_raw;

-- 4. Category validation
SELECT attrition, COUNT(*) FROM hr.employees_raw GROUP BY 1;
SELECT overtime,  COUNT(*) FROM hr.employees_raw GROUP BY 1;
SELECT performance_rating, COUNT(*) FROM hr.employees_raw GROUP BY 1 ORDER BY 1;

-- 5. Logical consistency (all should return 0)
SELECT COUNT(*) AS bad_tenure_logic
FROM hr.employees_raw
WHERE years_in_current_role       > years_at_company
   OR years_since_last_promotion  > years_at_company
   OR years_with_curr_manager     > years_at_company
   OR years_at_company            > total_working_years;

-- 6. Distributions that drive our thresholds
SELECT
    percentile_cont(ARRAY[0.25,0.5,0.75,0.9]) WITHIN GROUP (ORDER BY years_since_last_promotion) AS promo_gap_pctiles,
    percentile_cont(ARRAY[0.25,0.5,0.75,0.9]) WITHIN GROUP (ORDER BY years_with_curr_manager)    AS mgr_tenure_pctiles
FROM hr.employees_raw;

-- 7. Baseline attrition
SELECT COUNT(*) FILTER (WHERE attrition = 'Yes') AS leavers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE attrition = 'Yes') / COUNT(*), 1) AS attrition_pct
FROM hr.employees_raw;
