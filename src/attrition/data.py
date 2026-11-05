"""Loading and validating the cleaned HR attrition data."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

EXPECTED_ROWS = 1470
FLAG_COLUMNS = [
    "attrition_flag",
    "high_performer_flag",
    "overtime_flag",
    "promo_stagnation_flag",
    "new_manager_flag",
    "below_level_median_pay_flag",
]


def repo_root() -> Path:
    """Return the repository root (the folder that contains pyproject.toml)."""
    return Path(__file__).resolve().parents[2]


def default_clean_path() -> Path:
    """Location of the cleaned CSV exported from the SQL view hr.employees_clean."""
    return repo_root() / "data" / "processed" / "hr_attrition_clean.csv"


def validate_clean(df: pd.DataFrame) -> None:
    """Raise ValueError if the cleaned data does not match what the SQL view promises."""
    problems: list[str] = []

    if len(df) != EXPECTED_ROWS:
        problems.append(f"expected {EXPECTED_ROWS} rows, found {len(df)}")
    if df["employee_number"].duplicated().any():
        problems.append("employee_number is not unique")
    if df.isna().any().any():
        problems.append("the data contains missing values")

    for col in FLAG_COLUMNS:
        if not set(df[col].unique()) <= {0, 1}:
            problems.append(f"{col} contains values other than 0 and 1")

    if not set(df["performance_rating"].unique()) <= {3, 4}:
        problems.append("performance_rating contains values other than 3 and 4")

    expected_flag = (df["attrition"] == "Yes").astype(int)
    if not (df["attrition_flag"] == expected_flag).all():
        problems.append("attrition_flag does not match the attrition column")

    if problems:
        raise ValueError("Data validation failed: " + "; ".join(problems))


def load_clean(path: str | Path | None = None, validate: bool = True) -> pd.DataFrame:
    """Load hr_attrition_clean.csv and (by default) validate it."""
    csv_path = Path(path) if path is not None else default_clean_path()
    if not csv_path.exists():
        raise FileNotFoundError(
            f"Could not find {csv_path}. Export hr.employees_clean from PostgreSQL "
            "(see sql/04_composite_risk_export.sql) to data/processed/hr_attrition_clean.csv."
        )
    df = pd.read_csv(csv_path)
    if validate:
        validate_clean(df)
    return df
