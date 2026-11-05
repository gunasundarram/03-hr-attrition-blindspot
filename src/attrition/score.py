"""The composite attrition risk score.

Identical logic to sql/05_risk_score_validation.sql (employees_with_score view)
and to the DAX calculated columns in the Power BI file.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

# Points = observed attrition lift (percentage points) scaled to 100, rounded.
WEIGHTS: dict[str, int] = {
    "overtime_flag": 30,
    "new_manager_flag": 30,
    "no_stock_options_flag": 22,
    "low_job_satisfaction_flag": 12,
    "below_level_median_pay_flag": 6,
}

BAND_ORDER = ["Low", "Medium", "High", "Critical"]
# A band starts at its lower bound: Low 0-21, Medium 22-43, High 44-59, Critical 60+
BAND_LOWER_BOUNDS = {"Medium": 22, "High": 44, "Critical": 60}


def band_from_score(score: int | float) -> str:
    """Map a single risk score to its band."""
    if score >= BAND_LOWER_BOUNDS["Critical"]:
        return "Critical"
    if score >= BAND_LOWER_BOUNDS["High"]:
        return "High"
    if score >= BAND_LOWER_BOUNDS["Medium"]:
        return "Medium"
    return "Low"


def add_score(df: pd.DataFrame) -> pd.DataFrame:
    """Return a copy of df with the two derived flags, risk_score and risk_band added."""
    out = df.copy()
    out["no_stock_options_flag"] = (out["stock_option_level"] == 0).astype(int)
    out["low_job_satisfaction_flag"] = (out["job_satisfaction"] == 1).astype(int)

    out["risk_score"] = sum(out[col] * pts for col, pts in WEIGHTS.items())

    conditions = [
        out["risk_score"] >= BAND_LOWER_BOUNDS["Critical"],
        out["risk_score"] >= BAND_LOWER_BOUNDS["High"],
        out["risk_score"] >= BAND_LOWER_BOUNDS["Medium"],
    ]
    out["risk_band"] = np.select(conditions, ["Critical", "High", "Medium"], default="Low")
    out["risk_band"] = pd.Categorical(out["risk_band"], categories=BAND_ORDER, ordered=True)
    return out


def band_summary(scored: pd.DataFrame) -> pd.DataFrame:
    """Headcount, leavers and attrition rate per band (Low to Critical)."""
    summary = (
        scored.groupby("risk_band", observed=False)
        .agg(headcount=("attrition_flag", "size"), leavers=("attrition_flag", "sum"))
        .reset_index()
    )
    summary["attrition_pct"] = (100 * summary["leavers"] / summary["headcount"]).round(1)
    return summary


def current_at_risk(scored: pd.DataFrame) -> pd.DataFrame:
    """Employees who are still here (attrition == 'No') and in the High or Critical band."""
    mask = (scored["attrition"] == "No") & (scored["risk_band"].isin(["High", "Critical"]))
    return scored.loc[mask].copy()
