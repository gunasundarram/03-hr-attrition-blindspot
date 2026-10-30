-- ============================================================================
-- Project 03: The Attrition Blindspot
-- 05_risk_score_validation.sql
-- Re-computes the composite risk score in SQL so the Power BI (DAX) numbers can
-- be independently verified, and holds the queries behind each dashboard finding.
-- Depends on: hr.employees_clean (04_composite_risk_export.sql).
-- Run each query separately (highlight, F5).
-- ============================================================================

-- ============ PART A: Score view (mirrors the DAX columns exactly) ==========
-- Points = observed attrition lift scaled to 100:
--   overtime 30 | new manager (0 yrs) 30 | no stock options 22 |
--   job satisfaction = 1 -> 12 | pay below job-level median 6
-- High performer and promotion gap earn 0 points (no attrition lift).
-- Note: named employees_with_score so it cannot clash with any older
-- hr.employees_scored view you may have created while experimenting.
CREATE OR REPLACE VIEW hr.employees_with_score AS
WITH s AS (
    SELECT
        c.*,
        (c.stock_option_level = 0)::int AS no_stock_options_flag,
        (c.job_satisfaction   = 1)::int AS low_job_satisfaction_flag,
        ( 30 * c.overtime_flag
        + 30 * c.new_manager_flag
        + 22 * (c.stock_option_level = 0)::int
        + 12 * (c.job_satisfaction   = 1)::int
        +  6 * c.below_level_median_pay_flag ) AS risk_score
    FROM hr.employees_clean c
)
SELECT
    s.*,
    CASE WHEN s.risk_score >= 60 THEN 'Critical'
         WHEN s.risk_score >= 44 THEN 'High'
         WHEN s.risk_score >= 22 THEN 'Medium'
         ELSE 'Low' END AS risk_band
FROM s;

-- ============ PART B: Band validation (must match Power BI page 1 and 3) ====
-- Expected: Low 516 / 25 / 4.8 | Medium 606 / 78 / 12.9 | High 223 / 70 / 31.4 | Critical 125 / 64 / 51.2
SELECT risk_band,
       COUNT(*)            AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_with_score
GROUP BY risk_band
ORDER BY CASE risk_band WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2 WHEN 'High' THEN 3 ELSE 4 END;

-- Critical vs Low multiple (expect about 10.6x)
SELECT ROUND(
         (SELECT AVG(attrition_flag) FROM hr.employees_with_score WHERE risk_band = 'Critical')
       / (SELECT AVG(attrition_flag) FROM hr.employees_with_score WHERE risk_band = 'Low'), 1) AS critical_vs_low_multiple;

-- ============ PART C: Single-driver lifts behind the weights ================
-- Expect: overtime 30.5 vs 10.4 | new manager 32.3 vs 12.6 |
--         no stock options 24.4 vs 9.9 | job satisfaction 1: 22.8 vs 14.5 | below-level pay 18.4 vs 13.8
SELECT driver, flag, COUNT(*) AS n,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM (
    SELECT 'overtime'          AS driver, overtime_flag                    AS flag, attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'new_manager',        new_manager_flag,               attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'no_stock_options',   no_stock_options_flag,          attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'low_job_satisfaction', low_job_satisfaction_flag,    attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'below_level_pay',    below_level_median_pay_flag,    attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'high_performer',     high_performer_flag,            attrition_flag FROM hr.employees_with_score
    UNION ALL SELECT 'promo_stagnation',   promo_stagnation_flag,          attrition_flag FROM hr.employees_with_score
) t
GROUP BY driver, flag
ORDER BY driver, flag;

-- ============ PART D: The performance paradox (page 2) ======================
-- Expect: High(4) no OT 8.7% (n=161) / OT 35.4% (n=65, 23 leavers: directional)
--         Solid(3) no OT 10.8% / OT 29.6%
SELECT performance_label,
       overtime,
       COUNT(*)            AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY performance_label, overtime
ORDER BY performance_label, overtime;

-- ============ PART E: Overtime x manager tenure heatmap (page 3) ============
-- Expect: overtime Yes + New (0 yrs) = 52.4% (n=82)
SELECT overtime, manager_tenure_band,
       COUNT(*)            AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY overtime, manager_tenure_band
ORDER BY overtime DESC, manager_tenure_band;

-- ============ PART F: The first-year cliff (page 4) =========================
-- Expect: First-year employee 34.9% (n=215) | Established, new manager 23.0% (n=61)
--         | Established, same manager 12.4% (n=1194)
SELECT CASE WHEN years_at_company <= 1        THEN 'First-year employee'
            WHEN years_with_curr_manager = 0  THEN 'Established, new manager'
            ELSE 'Established, same manager' END AS tenure_group,
       COUNT(*)            AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY 1
ORDER BY attrition_pct DESC;

-- Share of "new manager" employees who are first-year staff (expect 76.8%)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE years_at_company <= 1) / COUNT(*), 1) AS first_year_share_pct
FROM hr.employees_clean
WHERE new_manager_flag = 1;

-- ============ PART G: Current at-risk staff (page 5) ========================
-- Expect: 214 current employees | 30 high performers | 139 on overtime | 114 with new manager
SELECT COUNT(*)                                             AS current_high_or_critical,
       COUNT(*) FILTER (WHERE high_performer_flag = 1)      AS high_performers,
       COUNT(*) FILTER (WHERE overtime_flag = 1)            AS on_overtime,
       COUNT(*) FILTER (WHERE new_manager_flag = 1)         AS new_manager
FROM hr.employees_with_score
WHERE attrition = 'No' AND risk_band IN ('High', 'Critical');

-- Where the next leavers are, by job role (expect Research Scientist 57 first)
SELECT job_role, COUNT(*) AS current_at_risk
FROM hr.employees_with_score
WHERE attrition = 'No' AND risk_band IN ('High', 'Critical')
GROUP BY job_role
ORDER BY current_at_risk DESC;

-- Action list (mirrors the Power BI "Recommended Action" column)
-- Expect 100 / 75 / 39 for the three actions below
SELECT CASE WHEN overtime_flag = 1 AND new_manager_flag = 1 THEN 'Cut overtime + 30/60/90-day check-ins'
            WHEN overtime_flag = 1                          THEN 'Review workload, cap overtime'
            WHEN new_manager_flag = 1                       THEN 'Onboarding + manager support'
            WHEN no_stock_options_flag = 1                  THEN 'Review equity package'
            WHEN low_job_satisfaction_flag = 1              THEN 'Stay interview: job satisfaction'
            ELSE 'Monitor' END AS suggested_action,
       COUNT(*) AS headcount
FROM hr.employees_with_score
WHERE attrition = 'No' AND risk_band IN ('High', 'Critical')
GROUP BY 1
ORDER BY headcount DESC;

-- ============ PART H: Attrition by job role (page 1) ========================
-- Expect: Sales Representative 39.8% (n=83) first, Research Director 2.5% last
SELECT job_role,
       COUNT(*)            AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * AVG(attrition_flag), 1) AS attrition_pct
FROM hr.employees_clean
GROUP BY job_role
ORDER BY attrition_pct DESC;
