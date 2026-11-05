"""Tests for data loading and validation."""

import pytest

from attrition.data import load_clean, validate_clean


def test_clean_data_loads_and_validates():
    df = load_clean()
    assert df.shape == (1470, 39)


def test_validation_catches_duplicate_ids():
    df = load_clean()
    df.loc[1, "employee_number"] = df.loc[0, "employee_number"]
    with pytest.raises(ValueError, match="employee_number is not unique"):
        validate_clean(df)


def test_validation_catches_bad_flag_values():
    df = load_clean()
    df.loc[0, "overtime_flag"] = 2
    with pytest.raises(ValueError, match="overtime_flag"):
        validate_clean(df)


def test_missing_file_gives_helpful_error(tmp_path):
    with pytest.raises(FileNotFoundError, match="sql/04_composite_risk_export.sql"):
        load_clean(tmp_path / "nope.csv")
