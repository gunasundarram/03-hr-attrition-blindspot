"""Reconciliation tests: the Python score must reproduce the SQL and Power BI numbers.

Expected values come from sql/05_risk_score_validation.sql and the dashboard (Pages 1, 3, 5).
"""

import pytest

from attrition.data import load_clean
from attrition.score import add_score, band_summary, current_at_risk


@pytest.fixture(scope="module")
def scored():
    return add_score(load_clean())


def test_row_count_and_baseline_attrition(scored):
    assert len(scored) == 1470
    assert scored["attrition_flag"].sum() == 237


def test_band_table_matches_sql_and_dashboard(scored):
    summary = band_summary(scored).set_index("risk_band")
    expected = {
        "Low": (516, 25, 4.8),
        "Medium": (606, 78, 12.9),
        "High": (223, 70, 31.4),
        "Critical": (125, 64, 51.2),
    }
    for band, (headcount, leavers, pct) in expected.items():
        assert summary.loc[band, "headcount"] == headcount
        assert summary.loc[band, "leavers"] == leavers
        assert summary.loc[band, "attrition_pct"] == pct


def test_current_at_risk_counts_match_page_5(scored):
    at_risk = current_at_risk(scored)
    assert len(at_risk) == 214
    assert (at_risk["high_performer_flag"] == 1).sum() == 30
    assert (at_risk["overtime_flag"] == 1).sum() == 139
    assert (at_risk["new_manager_flag"] == 1).sum() == 114
    assert (at_risk["risk_band"] == "Critical").sum() == 61
