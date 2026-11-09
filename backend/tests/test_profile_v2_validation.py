"""Profile input boundaries and field whitelists."""

import pytest
from pydantic import ValidationError

from app.api.me import PreferencesInput, ProfileInput


def test_profile_normalization_and_partial_update() -> None:
    value = ProfileInput(display_name="  Ada  ", username="  ADa_1  ", bio="  Hello\nthere  ")
    assert value.model_dump(exclude_unset=True) == {
        "display_name": "Ada", "username": "ada_1", "bio": "Hello\nthere",
    }
    assert ProfileInput(username=None).model_dump(exclude_unset=True) == {"username": None}
    assert ProfileInput().model_dump(exclude_unset=True) == {}


@pytest.mark.parametrize("input_data", [
    {"display_name": " "}, {"display_name": "x" * 51},
    {"username": "bad-name"}, {"username": "a"},
    {"bio": "x" * 161}, {"role": "admin"}, {"total_xp": 1000},
])
def test_profile_rejects_invalid_or_protected_fields(input_data: dict) -> None:
    with pytest.raises(ValidationError):
        ProfileInput.model_validate(input_data)


@pytest.mark.parametrize("input_data", [
    {"daily_goal_minutes": 0}, {"preferred_accent": "other"},
    {"interface_language": "xx"}, {"learning_goal": None},
    {"daily_goal_minutes": None}, {"user_id": "other"},
])
def test_preferences_reject_invalid_values(input_data: dict) -> None:
    with pytest.raises(ValidationError):
        PreferencesInput.model_validate(input_data)
