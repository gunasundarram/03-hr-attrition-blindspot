# Data Dictionary: The Attrition Blindspot

**Project 03** | IBM HR Analytics Employee Attrition dataset (Kaggle) | PostgreSQL + Power BI (DAX)

> **Synthetic data.** The source dataset was created by IBM data scientists. Every finding in this project is illustrative, not evidence about a real company.

| Item | Value |
|---|---|
| Rows | 1,470 employees (one row per employee) |
| Leavers | 237 (16.1%); 1,233 current employees |
| Source file | `data/raw/ibm_hr_attrition_raw.csv` (35 columns, original name `WA_Fn-UseC_-HR-Employee-Attrition.csv`) |
| Analytical file | `data/processed/hr_attrition_clean.csv` (39 columns) |
| Power BI table | `employees` (39 columns + calculated columns below) |

---

## 1. Data lineage

| Step | Object | Script / tool | Purpose |
|---|---|---|---|
| 1 | `hr.employees_raw` (table) | `sql/01_create_schema.sql`, `sql/02_load_data.sql` | Raw landing table, unchanged source values |
| 2 | Quality checks | `sql/03_data_quality_checks.sql` | Profiling before any modelling |
| 3 | `hr.employees_clean` (view) | `sql/04_composite_risk_export.sql` | Drops unused columns, adds flags and bands |
| 4 | `hr_attrition_clean.csv` | Export of the view | Input to Power BI |
| 5 | `hr.employees_with_score` (view) | `sql/05_risk_score_validation.sql` | SQL replica of the DAX score, used to verify dashboard numbers |
| 6 | `employees` + measures | `powerbi/hr_attrition_blindspot.pbix` | Dashboard, DAX risk score |

---

## 2. Data quality summary

| Check | Result |
|---|---|
| Row count / distinct `employee_number` | 1,470 / 1,470 (no duplicates) |
| Missing values in the 39 exported columns | 0 |
| Tenure logic (`years_in_current_role`, `years_since_last_promotion`, `years_with_curr_manager` greater than `years_at_company`, or `years_at_company` greater than `total_working_years`) | 0 violations |
| Constant columns | 3 (`employee_count`, `standard_hours`, `over18`), dropped |
| `performance_rating` values | Only **3** (1,244 employees) and **4** (226 employees). There are no 1s or 2s. |
| `attrition` values | No = 1,233, Yes = 237 |
| `overtime` values | No = 1,054, Yes = 416 |

---

## 3. Source columns kept (29)

Scales for the 1-4 survey fields follow the Kaggle dataset description. Units that the source does not state are marked "not stated".

| Column | Meaning | Scale / values (observed range) |
|---|---|---|
| `employee_number` | Unique employee ID (primary key) | Integer, 1 to 2068 (not contiguous) |
| `age` | Age in years | 18 to 60 |
| `gender` | Gender | Female / Male |
| `marital_status` | Marital status | Single / Married / Divorced |
| `department` | Department | Sales / Research & Development / Human Resources |
| `job_role` | Job role | 9 roles: Healthcare Representative, Human Resources, Laboratory Technician, Manager, Manufacturing Director, Research Director, Research Scientist, Sales Executive, Sales Representative |
| `job_level` | Seniority | 1 to 5 (5 = most senior) |
| `business_travel` | Travel frequency | Non-Travel / Travel_Rarely / Travel_Frequently |
| `distance_from_home` | Distance from home to work | 1 to 29 (unit not stated) |
| `education` | Education level | 1 = Below College, 2 = College, 3 = Bachelor, 4 = Master, 5 = Doctor |
| `education_field` | Field of education | Human Resources, Life Sciences, Marketing, Medical, Other, Technical Degree |
| `monthly_income` | Monthly pay | 1,009 to 19,999 (currency not stated) |
| `percent_salary_hike` | Most recent salary increase | 11 to 25 (percent) |
| `stock_option_level` | Stock option tier | 0 to 3 (0 = none) |
| `num_companies_worked` | Previous employers | 0 to 9 |
| `total_working_years` | Total career length | 0 to 40 years |
| `years_at_company` | Tenure at this company | 0 to 40 years |
| `years_in_current_role` | Time in current role | 0 to 18 years |
| `years_since_last_promotion` | Years since last promotion | 0 to 15 |
| `years_with_curr_manager` | Years with current manager | 0 to 17 |
| `training_times_last_year` | Training sessions last year | 0 to 6 |
| `environment_satisfaction` | Survey score | 1 = Low, 2 = Medium, 3 = High, 4 = Very High |
| `job_satisfaction` | Survey score | 1 = Low, 2 = Medium, 3 = High, 4 = Very High |
| `job_involvement` | Survey score | 1 = Low, 2 = Medium, 3 = High, 4 = Very High |
| `relationship_satisfaction` | Survey score | 1 = Low, 2 = Medium, 3 = High, 4 = Very High |
| `work_life_balance` | Survey score | 1 = Bad, 2 = Good, 3 = Better, 4 = Best |
| `performance_rating` | Latest performance rating | 1 = Low, 2 = Good, 3 = Excellent, 4 = Outstanding. **Only 3 and 4 exist in this data.** |
| `overtime` | Works overtime | Yes / No |
| `attrition` | Left the company | Yes / No |

---

## 4. Engineered columns created in SQL (10)

Defined in the view `hr.employees_clean`.

| Column | Definition | Justification / evidence |
|---|---|---|
| `attrition_flag` | 1 if `attrition = 'Yes'`, else 0 | Numeric outcome for averages and DAX |
| `high_performer_flag` | 1 if `performance_rating = 4` | Only ratings 3 and 4 exist; rating 4 is 226 employees (15.4%). **Scored 0 points:** attrition is 16.4% vs 16.1% for everyone else. |
| `overtime_flag` | 1 if `overtime = 'Yes'` | Attrition 30.5% with overtime vs 10.4% without (n = 416 / 1,054). Scored 30 points. |
| `new_manager_flag` | 1 if `years_with_curr_manager = 0` | Attrition 32.3% at 0 years (n = 263) vs 12.6% at 1+ years. Year 1 (14.5%) is at baseline, so the threshold is `= 0`, not `<= 1`. **77% of flagged employees are first-year staff** (`years_at_company <= 1`); for established staff the effect is 23.0% vs 12.4% (n = 61). Scored 30 points. |
| `promo_stagnation_flag` | 1 if `years_since_last_promotion >= 3` | **Reference only, not scored.** Tested and rejected: 13.7% flagged vs 17.0% not flagged, and no trend by year. |
| `below_level_median_pay_flag` | 1 if `monthly_income` is below the median income of the same `job_level` | Fair-pay comparison within level. Attrition 18.4% vs 13.8%. Scored 6 points. |
| `tenure_band` | `0-1 yrs` / `2-4 yrs` / `5-9 yrs` / `10+ yrs` from `years_at_company` | Slicer and axis grouping |
| `promo_gap_band` | `Promoted this year` / `1-2 yrs` / `3-4 yrs` / `5+ yrs` from `years_since_last_promotion` | Slicer and axis grouping |
| `manager_tenure_band` | `New (0 yrs)` / `1-4 yrs` / `5+ yrs` from `years_with_curr_manager` | Separates the year-0 spike from normal manager tenure |
| `performance_label` | `High (4)` if rating 4, else `Solid (3)` | Readable label |

---

## 5. Composite risk score

Points are each driver's observed attrition lift (percentage points), scaled so the total is 100 and rounded.

| Driver | Definition | Attrition if present vs absent | Lift (pts) | Points |
|---|---|---|---|---|
| Overtime | `overtime_flag = 1` | 30.5% vs 10.4% | +20.1 | **30** |
| New manager | `new_manager_flag = 1` | 32.3% vs 12.6% | +19.7 | **30** |
| No stock options | `stock_option_level = 0` | 24.4% vs 9.9% | +14.5 | **22** |
| Lowest job satisfaction | `job_satisfaction = 1` | 22.8% vs 14.5% | +8.4 | **12** |
| Pay below level median | `below_level_median_pay_flag = 1` | 18.4% vs 13.8% | +4.6 | **6** |
| High performer | `high_performer_flag = 1` | 16.4% vs 16.1% | none | 0 |
| Promotion stagnation | `promo_stagnation_flag = 1` | 13.7% vs 17.0% | none | 0 |

**Formula:** `risk_score = 30*overtime + 30*new_manager + 22*no_stock_options + 12*job_satisfaction_1 + 6*below_level_pay`

| Risk band | Score | Employees | Leavers | Attrition |
|---|---|---|---|---|
| Low | 0 to 21 | 516 | 25 | 4.8% |
| Medium | 22 to 43 | 606 | 78 | 12.9% |
| High | 44 to 59 | 223 | 70 | 31.4% |
| Critical | 60 and above | 125 | 64 | 51.2% |

Critical-band attrition is 10.6 times the Low band. Current employees (`attrition = 'No'`) in the High or Critical bands: **214** (61 Critical, 153 High).

---

## 6. Calculated columns in Power BI (DAX, table `employees`)

| Column | Logic | Notes |
|---|---|---|
| `No Stock Options Flag` | 1 if `stock_option_level = 0` | Mirrors `no_stock_options_flag` in `employees_with_score` |
| `Low Job Satisfaction Flag` | 1 if `job_satisfaction = 1` | Mirrors `low_job_satisfaction_flag` |
| `Risk Score` | Weighted sum above | Matches `risk_score` in SQL |
| `Risk Band` | `>= 60` Critical, `>= 44` High, `>= 22` Medium, else Low | Matches `risk_band` in SQL |
| `Risk Band Order` | 1 to 4 from `Risk Score` | Sort-by column for `Risk Band`. Built from `Risk Score`, never from `Risk Band` (that causes a circular dependency). |
| `Manager Band Order` | 1 to 3 from `years_with_curr_manager` | Sort-by column for `manager_tenure_band` |
| `Tenure Group` | `First-year employee` (`years_at_company <= 1`), else `Established, new manager` (`years_with_curr_manager = 0`), else `Established, same manager` | Page 4 decomposition: 215 / 61 / 1,194 employees |
| `Recommended Action` | Rule order: overtime and new manager, overtime, new manager, no stock options, low satisfaction, else Monitor | Page 5. Current at-risk staff split 39 / 100 / 75 across the first three actions. |

---

## 7. DAX measures (table `_Measures`)

| Measure | Definition |
|---|---|
| `Headcount` | Count of employee rows |
| `Leavers` | Sum of `attrition_flag` |
| `Attrition Rate` | `Leavers / Headcount` |
| `Avg Risk Score` | Average of `Risk Score` |
| `Critical Attrition` | `Attrition Rate` where `Risk Band = Critical` |
| `Low Attrition` | `Attrition Rate` where `Risk Band = Low` |
| `Risk Multiple` | `Critical Attrition / Low Attrition`, formatted as text (for example 10.6x) |
| `Current Critical Staff` | Headcount where `attrition = No` and `Risk Band = Critical` |
| `Current Staff at High or Critical Risk` | Headcount where `attrition = No` and `Risk Band` is High or Critical |
| `High Performers` | Headcount where `high_performer_flag = 1` |
| `High Performer Attrition` | `Attrition Rate` for high performers |
| `High Performers on Overtime` | Headcount where high performer and `overtime_flag = 1` |
| `Current High Performers at Risk` | Current staff, high performers, High or Critical band |
| `New Manager Attrition` | `Attrition Rate` where `new_manager_flag = 1` |
| `First-Year Share of New Manager` | Share of `new_manager_flag = 1` employees with `years_at_company <= 1` |
| `Established New Manager Attrition` | `Attrition Rate` where `new_manager_flag = 1` and `years_at_company >= 2` |
| `Promo Stagnation Attrition` | `Attrition Rate` where `promo_stagnation_flag = 1` |
| `At-Risk Staff on Overtime` | Headcount where `overtime_flag = 1` (Page 5 page filter limits to current High or Critical staff) |
| `At-Risk Staff with New Manager` | Headcount where `new_manager_flag = 1` (same page filter) |
| `Rate with N` | Text label combining `Attrition Rate` and `Headcount`, for example `52.4% (n=82)` |
| `Risk Colour` | Hex colour by `Risk Band`, drives bar and table colouring |
| `Manager Year Colour` | Red for year 0, grey otherwise |
| `Risk Climb Title` / `Job Role Title` | Dynamic chart titles on Page 1 |

Page 5 uses page-level filters: `attrition = No` and `Risk Band` in High, Critical.

---

## 8. Dropped columns

| Column | Reason |
|---|---|
| `employee_count` | Constant (always 1), no information |
| `standard_hours` | Constant (always 80), no information |
| `over18` | Constant (always `Y`), no information |
| `daily_rate`, `hourly_rate`, `monthly_rate` | Not meaningful pay measures in this dataset; `monthly_income` is used instead |

---

## 9. Known limitations

- **Synthetic data**, so no real-world conclusions.
- **In-sample weights:** the score weights were derived from the same 1,470 records the bands are tested on. The score is a prioritisation tool, not a validated forecast.
- **Associations, not causes:** overtime, first-year status and manager change overlap.
- **Small cells (directional only):** high performers on overtime, 35.4% (n = 65, 23 leavers, margin of error about 12 points); established staff with a new manager, 23.0% (n = 61, 14 leavers). Combinations under about 30 employees are low confidence, for example the 100% cell with n = 1.
- **Performance rating** has only two values here, so "high performer" means rating 4.
- **Unstated units:** `distance_from_home` and the currency of `monthly_income` are not stated in the source.
