# Data Dictionary — HR Attrition Blindspot

Source: IBM HR Analytics Employee Attrition dataset (Kaggle). Synthetic data
created by IBM data scientists; findings are illustrative, not real-company evidence.
Rows: 1,470 employees. Overall attrition: 16.1% (237 leavers).

## Source columns kept

| Column | Meaning | Scale / values |
|---|---|---|
| employee_number | Unique employee ID | Integer |
| age | Employee age | Years |
| gender | Gender | Male / Female |
| marital_status | Marital status | Single / Married / Divorced |
| department | Department | Sales / R&D / HR |
| job_role | Job role | 9 roles |
| job_level | Seniority | 1-5 |
| business_travel | Travel frequency | Non-Travel / Travel_Rarely / Travel_Frequently |
| distance_from_home | Distance from home | Miles/km (unit not stated in source) |
| education, education_field | Education level and field | Level 1-5; field text |
| monthly_income | Monthly pay | Integer |
| percent_salary_hike | Last salary increase | Percent |
| stock_option_level | Stock option tier | 0-3 |
| num_companies_worked | Previous employers | Integer |
| total_working_years | Total career length | Years |
| years_at_company | Tenure at company | Years |
| years_in_current_role | Time in current role | Years |
| years_since_last_promotion | Years since last promotion | 0-15 |
| years_with_curr_manager | Years with current manager | 0-17 |
| training_times_last_year | Training sessions last year | Integer |
| environment_satisfaction | Survey score | 1 = Low ... 4 = Very High |
| job_satisfaction | Survey score | 1 = Low ... 4 = Very High |
| job_involvement | Survey score | 1 = Low ... 4 = Very High |
| relationship_satisfaction | Survey score | 1 = Low ... 4 = Very High |
| work_life_balance | Survey score | 1 = Bad ... 4 = Best |
| performance_rating | Latest performance rating | 3 = Excellent, 4 = Outstanding (no 1s or 2s exist) |
| overtime | Works overtime | Yes / No |
| attrition | Left the company | Yes / No |

## Engineered columns

| Column | Definition | Justification |
|---|---|---|
| attrition_flag | 1 if attrition = 'Yes' else 0 | Numeric outcome for DAX and averages |
| high_performer_flag | 1 if performance_rating = 4 | Only 3 and 4 exist; rating 4 = 226 employees (15.4%) |
| overtime_flag | 1 if overtime = 'Yes' | Attrition 30.5% with overtime vs 10.4% without (n = 416 vs 1,054) |
| promo_stagnation_flag | 1 if years_since_last_promotion >= 3 | Kept for reference only. Tested and rejected: no relationship with attrition (13.7% flagged vs 17.0% not flagged; no trend by year). Not used in the risk score. |
| new_manager_flag | 1 if years_with_curr_manager = 0 | Attrition 32.3% at 0 yrs (n = 263) vs 12.6% at 1+ yrs. Year 1 (14.5%) is at baseline, so the threshold is 0, not <= 1. Overlaps with new hires. |
| below_level_median_pay_flag | 1 if income < median income for the same job_level | Fair-pay comparison within level |
| tenure_band | 0-1 / 2-4 / 5-9 / 10+ yrs at company | For slicers and chart axes |
| promo_gap_band | Promoted this year / 1-2 / 3-4 / 5+ yrs | For slicers and chart axes |
| manager_tenure_band | New (0 yrs) / 1-4 yrs / 5+ yrs | Separates the 0-year spike from normal manager tenure |
| performance_label | 'High (4)' or 'Solid (3)' | Readable label |

## Dropped columns

| Column | Reason |
|---|---|
| employee_count | Constant (always 1), no information |
| standard_hours | Constant (always 80), no information |
| over18 | Constant (always 'Y'), no information |
| daily_rate, hourly_rate, monthly_rate | Not meaningful pay measures in this dataset; monthly_income is used instead |

## Data notes

- Overall attrition is 16.1% (237 of 1,470).
- Combinations with fewer than 30 employees are treated as low confidence in the analysis.
