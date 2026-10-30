-- ============================================================================
-- Project 03: The Attrition Blindspot
-- 04_composite_risk_export.sql
-- Threshold testing, the clean analytical view, combination analysis and the
-- export that feeds Power BI. Run each query separately (highlight, F5).
-- ============================================================================

-- ============ PART A: Threshold testing (run BEFORE building the view) ======
-- Finding: attrition spikes ONLY at 0 years with the current manager (32.3%).
-- Year 1 (14.5%) sits at baseline, so the new-manager flag uses = 0, not <= 1.
SELECT years_with_curr_manager AS yrs,
       COUNT(*) AS n,
       ROUND(100.0 * AVG((attrition = 'Yes')::int), 1) AS attrition_pct
FROM hr.employees_raw
GROUP BY 1 ORDER BY 1;

-- Finding: years since last promotion shows NO trend (values bounce 0-23%).
-- Promotion stagnation was tested and rejected as a risk driver.
SELECT years_since_last_promotion AS yrs,
       COUNT(*) AS n,
       ROUND(100.0 * AVG((attrition = 'Yes')::int), 1) AS attrition_pct
FROM hr.employees_raw
GROUP BY 1 ORDER BY 1;


-- ============ PART B: Clean analytical view (39 columns) ====================
-- CREATE OR REPLACE keeps dependent views (for example a leftover
-- hr.employees_scored) intact. If you ever change the column list, run
--   DROP VIEW hr.employees_clean CASCADE;
-- first, then re-create this view and the view in 05_risk_score_validation.sql.
CREATE OR REPLACE VIEW hr.employees_clean AS
WITH level_pay AS (
    SELECT job_level,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY monthly_income) AS median_income
    FROM hr.employees_raw
    GROUP BY job_level
)
SELECT
    e.employee_number,
    e.age,
    e.gender,
    e.marital_status,
    e.department,
    e.job_role,
    e.job_level,
    e.business_travel,
    e.distance_from_home,
    e.education,
    e.education_field,
    e.monthly_income,
    e.percent_salary_hike,
    e.stock_option_level,
    e.num_companies_worked,
    e.total_working_years,
    e.years_at_company,
    e.years_in_current_role,
    e.years_since_last_promotion,
    e.years_with_curr_manager,
    e.training_times_last_year,
    e.environment_satisfaction,
    e.job_satisfaction,
    e.job_involvement,
    e.relationship_satisfaction,
    e.work_life_balance,
    e.performance_rating,
    e.overtime,
    e.attrition,

    -- Binary outcome
    (e.attrition = 'Yes')::int                  AS attrition_flag,

    -- Risk-driver flags
    (e.performance_rating = 4)::int             AS high_performer_flag,
    (e.overtime = 'Yes')::int                   AS overtime_flag,
    (e.years_since_last_promotion >= 3)::int    AS promo_stagnation_flag,   -- reference only, NOT scored
    (e.years_with_curr_manager = 0)::int        AS new_manager_flag,
    (e.monthly_income < lp.median_income)::int  AS below_level_median_pay_flag,

    -- Readable bands for slicers and chart axes
    CASE WHEN e.years_at_company < 2  THEN '0-1 yrs'
         WHEN e.years_at_company < 5  THEN '2-4 yrs'
         WHEN e.years_at_company < 10 THEN '5-9 yrs'
         ELSE '10+ yrs' END                     AS tenure_band,
    CASE WHEN e.years_since_last_promotion = 0  THEN 'Promoted this year'
         WHEN e.years_since_last_promotion <= 2 THEN '1-2 yrs'
         WHEN e.years_since_last_promotion <= 4 THEN '3-4 yrs'
         ELSE '5+ yrs' END                      AS promo_gap_band,
    CASE WHEN e.years_with_curr_manager = 0     THEN 'New (0 yrs)'
         WHEN e.years_with_curr_manager <= 4    THEN '1-4 yrs'
         ELSE '5+ yrs' END                      AS manager_tenure_band,
    CASE WHEN e.performance_rating = 4 THEN 'High (4)' ELSE 'Solid (3)' END AS performance_label
FROM hr.employees_raw e
JOIN level_pay lp USING (job_level);
-- employee_count, standard_hours, over18 (constants) and daily_rate, hourly_rate,
-- monthly_rate (not meaningful pay measures) are intentionally excluded.

-- Quick check: expect 1470 rows and 39 columns
SELECT COUNT(*) AS rows_in_view FROM hr.employees_clean;


-- ============ PART C: Combination analysis (core evidence) ==================
-- Combinations with fewer than ~30 employees are LOW CONFIDENCE:
-- do not headline them (for example the 100% row with n = 1).
SELECT
    high_performer_flag   AS hp,
    overtime_flag         AS ot,
    promo_stagnation_flag AS promo,
    new_manager_flag      AS new_mgr,
    COUNT(*)              AS headcount,
    SUM(attrition_flag)   AS leavers,
    ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY 1, 2, 3, 4
ORDER BY attrition_pct DESC, headcount DESC;

-- Marginal effect of each flag on its own
SELECT 'high_performer'   AS driver, high_performer_flag   AS flag, COUNT(*) AS n,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean GROUP BY high_performer_flag
UNION ALL
SELECT 'overtime', overtime_flag, COUNT(*), ROUND(100.0 * AVG(attrition_flag), 1)
FROM hr.employees_clean GROUP BY overtime_flag
UNION ALL
SELECT 'promo_stagnation', promo_stagnation_flag, COUNT(*), ROUND(100.0 * AVG(attrition_flag), 1)
FROM hr.employees_clean GROUP BY promo_stagnation_flag
UNION ALL
SELECT 'new_manager', new_manager_flag, COUNT(*), ROUND(100.0 * AVG(attrition_flag), 1)
FROM hr.employees_clean GROUP BY new_manager_flag
ORDER BY 1, 2;
-- Expected: high_performer 16.1 / 16.4 | overtime 10.4 / 30.5 |
--           promo_stagnation 17.0 / 13.7 (reversed: no signal) | new_manager 12.6 / 32.3


-- ============ PART D: Export for Power BI ===================================
-- Run this query, then in the results grid press F8 (Download as CSV) and save as
--   data/processed/hr_attrition_clean.csv
-- Expect 1470 rows + header; every *_flag column is 0 or 1.
SELECT * FROM hr.employees_clean ORDER BY employee_number;
