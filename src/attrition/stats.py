"""Statistical rigour for the headline findings: confidence intervals, tests and power.

Choices (and why):
* Wilson score interval for a single rate: reliable at small n, unlike the plain +/- 1.96*SE interval.
* Newcombe hybrid-score interval for a difference of two rates: built on Wilson intervals, stays inside [-1, 1].
* Fisher exact test (plus chi-square) for 2x2 tables: several comparison groups have fewer than 100 people.
* Odds ratio with Woolf (log) confidence interval from statsmodels Table2x2.
* Benjamini-Hochberg false discovery rate across the family of driver tests, so seven tests are not read as seven
  independent chances to find something.
* Bootstrap interval as a cross-check on the analytic one.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from scipy import stats
from statsmodels.stats.contingency_tables import Table2x2
from statsmodels.stats.multitest import multipletests
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import (
    confint_proportions_2indep,
    proportion_confint,
    proportion_effectsize,
)

OUTCOME = "attrition_flag"


def wilson_ci(successes: int, n: int, alpha: float = 0.05) -> tuple[float, float]:
    """Wilson score confidence interval for a proportion."""
    low, high = proportion_confint(successes, n, alpha=alpha, method="wilson")
    return float(low), float(high)


@dataclass
class Comparison:
    label: str
    n_exposed: int
    leavers_exposed: int
    rate_exposed: float
    n_reference: int
    leavers_reference: int
    rate_reference: float
    diff_pp: float
    diff_ci_low_pp: float
    diff_ci_high_pp: float
    odds_ratio: float
    or_ci_low: float
    or_ci_high: float
    p_fisher: float
    p_chi2: float


def compare(
    df: pd.DataFrame,
    exposed: pd.Series,
    reference: pd.Series,
    label: str,
    outcome: str = OUTCOME,
    alpha: float = 0.05,
) -> Comparison:
    """Compare attrition between an exposed group and a reference group (boolean masks)."""
    y1 = df.loc[exposed, outcome]
    y0 = df.loc[reference, outcome]
    a, n1 = int(y1.sum()), int(len(y1))
    c, n0 = int(y0.sum()), int(len(y0))

    p1, p0 = a / n1, c / n0
    diff_low, diff_high = confint_proportions_2indep(a, n1, c, n0, method="newcomb", alpha=alpha)

    table = np.array([[a, n1 - a], [c, n0 - c]])
    odds = Table2x2(table)
    or_low, or_high = odds.oddsratio_confint(alpha=alpha)
    p_fisher = stats.fisher_exact(table)[1]
    p_chi2 = stats.chi2_contingency(table, correction=False)[1]

    return Comparison(
        label=label,
        n_exposed=n1, leavers_exposed=a, rate_exposed=p1,
        n_reference=n0, leavers_reference=c, rate_reference=p0,
        diff_pp=100 * (p1 - p0),
        diff_ci_low_pp=100 * float(diff_low), diff_ci_high_pp=100 * float(diff_high),
        odds_ratio=float(odds.oddsratio),
        or_ci_low=float(or_low), or_ci_high=float(or_high),
        p_fisher=float(p_fisher), p_chi2=float(p_chi2),
    )


def comparison_table(comparisons: list[Comparison], fdr_alpha: float = 0.05) -> pd.DataFrame:
    """Tabulate comparisons and add Benjamini-Hochberg adjusted q-values (Fisher p-values)."""
    table = pd.DataFrame([asdict(c) for c in comparisons])
    reject, q, _, _ = multipletests(table["p_fisher"], alpha=fdr_alpha, method="fdr_bh")
    table["q_bh"] = q
    table["significant_after_fdr"] = reject
    return table


def driver_table(df: pd.DataFrame, drivers: dict[str, str]) -> pd.DataFrame:
    """Single-driver comparisons (flag == 1 vs flag == 0) with FDR correction.

    drivers maps a readable label to a 0/1 flag column.
    """
    comps = [compare(df, df[col] == 1, df[col] == 0, label) for label, col in drivers.items()]
    return comparison_table(comps)


def bootstrap_diff_ci(
    outcome_exposed: np.ndarray,
    outcome_reference: np.ndarray,
    n_boot: int = 10_000,
    seed: int = 42,
    alpha: float = 0.05,
) -> tuple[float, float]:
    """Percentile bootstrap CI for the difference in rates (exposed minus reference), in points."""
    rng = np.random.default_rng(seed)
    e = np.asarray(outcome_exposed)
    r = np.asarray(outcome_reference)
    diffs = np.empty(n_boot)
    for i in range(n_boot):
        diffs[i] = rng.choice(e, size=e.size).mean() - rng.choice(r, size=r.size).mean()
    low, high = np.percentile(diffs, [100 * alpha / 2, 100 * (1 - alpha / 2)])
    return 100 * float(low), 100 * float(high)


def minimum_detectable_difference(
    baseline_rate: float, n_exposed: int, n_reference: int, alpha: float = 0.05, power: float = 0.8
) -> float:
    """Smallest absolute difference (in points) detectable with the given power (two-sided).

    Answers: "if a real gap existed, how big would it have to be for this sample to find it?"
    """
    h = NormalIndPower().solve_power(
        effect_size=None, nobs1=n_exposed, alpha=alpha, power=power,
        ratio=n_reference / n_exposed, alternative="two-sided",
    )
    p_alt = float(np.sin(np.arcsin(np.sqrt(baseline_rate)) + h / 2) ** 2)
    return 100 * (p_alt - baseline_rate)


def interaction_test(df: pd.DataFrame, a: str, b: str, outcome: str = OUTCOME) -> dict[str, float]:
    """Logistic regression with an interaction term a:b.

    Tests whether the effect of `b` differs between the two levels of `a`.
    """
    model = smf.logit(f"{outcome} ~ {a} * {b}", data=df).fit(disp=0)
    term = f"{a}:{b}"
    low, high = np.exp(model.conf_int().loc[term])
    return {
        "interaction_odds_ratio": float(np.exp(model.params[term])),
        "or_ci_low": float(low),
        "or_ci_high": float(high),
        "p_value": float(model.pvalues[term]),
    }


def effect_size_h(p1: float, p2: float) -> float:
    """Cohen's h for two proportions (convenience wrapper)."""
    return float(proportion_effectsize(p1, p2))
