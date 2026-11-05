"""Tests for the statistics module: textbook values, cross-checks and data reconciliation."""

import math

import numpy as np
import pandas as pd
import pytest
from scipy import stats

from attrition.data import load_clean
from attrition.score import add_score
from attrition.stats import (
    bootstrap_diff_ci,
    compare,
    comparison_table,
    interaction_test,
    minimum_detectable_difference,
    wilson_ci,
)


def _manual_wilson(x, n, z=1.959963984540054):
    p = x / n
    centre = (p + z**2 / (2 * n)) / (1 + z**2 / n)
    half = z * math.sqrt(p * (1 - p) / n + z**2 / (4 * n**2)) / (1 + z**2 / n)
    return centre - half, centre + half


@pytest.mark.parametrize("x, n", [(23, 65), (0, 10), (10, 10), (237, 1470)])
def test_wilson_matches_textbook_formula(x, n):
    low, high = wilson_ci(x, n)
    m_low, m_high = _manual_wilson(x, n)
    assert low == pytest.approx(m_low, abs=1e-9)
    assert high == pytest.approx(m_high, abs=1e-9)


def _toy():
    df = pd.DataFrame({"attrition_flag": [1] * 10 + [0] * 40 + [1] * 5 + [0] * 45,
                       "group": ["a"] * 50 + ["b"] * 50})
    return df, df["group"] == "a", df["group"] == "b"


def test_compare_known_counts():
    df, exposed, reference = _toy()
    result = compare(df, exposed, reference, "toy")
    assert result.rate_exposed == pytest.approx(0.20)
    assert result.rate_reference == pytest.approx(0.10)
    assert result.diff_pp == pytest.approx(10.0)
    assert result.odds_ratio == pytest.approx((10 * 45) / (40 * 5))
    assert result.p_fisher == pytest.approx(stats.fisher_exact([[10, 40], [5, 45]])[1])
    assert result.diff_ci_low_pp < result.diff_pp < result.diff_ci_high_pp


def test_fdr_q_values_are_never_below_p_values():
    df, exposed, reference = _toy()
    table = comparison_table([compare(df, exposed, reference, "a"), compare(df, exposed, reference, "b")])
    assert (table["q_bh"] >= table["p_fisher"] - 1e-12).all()


def test_bootstrap_is_reproducible_and_brackets_the_estimate():
    e = np.array([1] * 20 + [0] * 80)
    r = np.array([1] * 10 + [0] * 90)
    first = bootstrap_diff_ci(e, r, n_boot=2000, seed=1)
    second = bootstrap_diff_ci(e, r, n_boot=2000, seed=1)
    assert first == second
    assert first[0] < 10.0 < first[1]


def test_smaller_samples_need_bigger_effects():
    small = minimum_detectable_difference(0.16, 100, 500)
    large = minimum_detectable_difference(0.16, 400, 2000)
    assert small > large > 0


# ---- reconciliation with the dashboard and README numbers ----
@pytest.fixture(scope="module")
def scored():
    return add_score(load_clean())


def test_rating_gap_matches_dashboard(scored):
    result = compare(scored, scored["high_performer_flag"] == 1, scored["high_performer_flag"] == 0, "rating")
    assert (result.leavers_exposed, result.n_exposed) == (37, 226)
    assert (result.leavers_reference, result.n_reference) == (200, 1244)
    assert round(result.diff_pp, 1) == 0.3


def test_overtime_counts_match_dashboard(scored):
    result = compare(scored, scored["overtime_flag"] == 1, scored["overtime_flag"] == 0, "overtime")
    assert (result.n_exposed, result.n_reference) == (416, 1054)
    assert round(100 * result.rate_exposed, 1) == 30.5
    assert round(100 * result.rate_reference, 1) == 10.4


def test_paradox_interaction_is_not_significant(scored):
    result = interaction_test(scored, "high_performer_flag", "overtime_flag")
    assert result["p_value"] == pytest.approx(0.229, abs=0.001)
    assert result["or_ci_low"] < 1.0 < result["or_ci_high"]
