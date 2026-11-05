"""Unit tests for the risk score logic (no data file needed)."""

import pandas as pd
import pytest

from attrition.score import WEIGHTS, add_score, band_from_score


def test_weights_sum_to_100():
    assert sum(WEIGHTS.values()) == 100


@pytest.mark.parametrize(
    "score, band",
    [(0, "Low"), (21, "Low"), (22, "Medium"), (43, "Medium"),
     (44, "High"), (59, "High"), (60, "Critical"), (100, "Critical")],
)
def test_band_boundaries(score, band):
    assert band_from_score(score) == band


def _one_row(**overrides):
    base = {
        "overtime_flag": 0, "new_manager_flag": 0, "below_level_median_pay_flag": 0,
        "stock_option_level": 1, "job_satisfaction": 3,
    }
    base.update(overrides)
    return pd.DataFrame([base])


def test_zero_risk_employee_scores_zero():
    assert add_score(_one_row()).loc[0, "risk_score"] == 0


def test_maximum_risk_employee_scores_100():
    row = _one_row(overtime_flag=1, new_manager_flag=1, below_level_median_pay_flag=1,
                   stock_option_level=0, job_satisfaction=1)
    scored = add_score(row)
    assert scored.loc[0, "risk_score"] == 100
    assert scored.loc[0, "risk_band"] == "Critical"


def test_overtime_plus_new_manager_alone_is_critical():
    scored = add_score(_one_row(overtime_flag=1, new_manager_flag=1))
    assert scored.loc[0, "risk_score"] == 60
    assert scored.loc[0, "risk_band"] == "Critical"


def test_only_stock_options_gap_is_medium():
    scored = add_score(_one_row(stock_option_level=0))
    assert scored.loc[0, "risk_score"] == 22
    assert scored.loc[0, "risk_band"] == "Medium"
