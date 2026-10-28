-- ============ PART A: Threshold sensitivity (run first, decide, then build the view) ============
-- Promotion stagnation: where does attrition separate?
SELECT years_since_last_promotion AS yrs,
       COUNT(*) AS n,
       ROUND(100.0 * AVG((attrition='Yes')::int), 1) AS attrition_pct
FROM hr.employees_raw
GROUP BY 1 ORDER BY 1;

-- Manager tenure
SELECT years_with_curr_manager AS yrs,
       COUNT(*) AS n,
       ROUND(100.0 * AVG((attrition='Yes')::int), 1) AS attrition_pct
FROM hr.employees_raw
GROUP BY 1 ORDER BY 1;

-- ============ PART B: Clean analytical view ============
DROP VIEW IF EXISTS hr.employees_clean;

CREATE VIEW hr.employees_clean AS
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
    (e.attrition = 'Yes')::int AS attrition_flag,

    -- Risk-driver flags (thresholds: adjust after reviewing Part A)
    (e.performance_rating = 4)::int            AS high_performer_flag,
    (e.overtime = 'Yes')::int                  AS overtime_flag,
    (e.years_since_last_promotion >= 3)::int   AS promo_stagnation_flag,
    (e.years_with_curr_manager <= 1)::int      AS new_manager_flag,
    (e.monthly_income < lp.median_income)::int AS below_level_median_pay_flag,

    -- Readable bands for slicers/axes
    CASE WHEN e.years_at_company < 2  THEN '0-1 yrs'
         WHEN e.years_at_company < 5  THEN '2-4 yrs'
         WHEN e.years_at_company < 10 THEN '5-9 yrs'
         ELSE '10+ yrs' END AS tenure_band,
    CASE WHEN e.years_since_last_promotion = 0  THEN 'Promoted this year'
         WHEN e.years_since_last_promotion <= 2 THEN '1-2 yrs'
         WHEN e.years_since_last_promotion <= 4 THEN '3-4 yrs'
         ELSE '5+ yrs' END AS promo_gap_band,
    CASE WHEN e.years_with_curr_manager <= 1 THEN '0-1 yrs'
         WHEN e.years_with_curr_manager <= 4 THEN '2-4 yrs'
         ELSE '5+ yrs' END AS manager_tenure_band,
    CASE WHEN e.performance_rating = 4 THEN 'High (4)' ELSE 'Solid (3)' END AS performance_label
FROM hr.employees_raw e
JOIN level_pay lp USING (job_level);
-- employee_count, standard_hours and over18 are intentionally dropped (constant columns)

-- ============ PART C: Combination analysis (the core evidence) ============
SELECT
    high_performer_flag AS hp,
    overtime_flag       AS ot,
    promo_stagnation_flag AS promo,
    new_manager_flag    AS new_mgr,
    COUNT(*)            AS headcount,
    SUM(attrition_flag) AS leavers,
    ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY 1,2,3,4
ORDER BY attrition_pct DESC, headcount DESC;

-- Marginal effect of each driver (single-factor attrition lift)
SELECT 'high_performer' AS driver, high_performer_flag AS flag, COUNT(*) n,
       ROUND(100.0*AVG(attrition_flag),1) AS attrition_pct FROM hr.employees_clean GROUP BY 2
UNION ALL
SELECT 'overtime', overtime_flag, COUNT(*), ROUND(100.0*AVG(attrition_flag),1) FROM hr.employees_clean GROUP BY 2
UNION ALL
SELECT 'promo_stagnation', promo_stagnation_flag, COUNT(*), ROUND(100.0*AVG(attrition_flag),1) FROM hr.employees_clean GROUP BY 2
UNION ALL
SELECT 'new_manager', new_manager_flag, COUNT(*), ROUND(100.0*AVG(attrition_flag),1) FROM hr.employees_clean GROUP BY 2
ORDER BY 1, 2;
