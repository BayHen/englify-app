from app.writing.rules import check


def test_structured_rules_and_paragraph_guidance() -> None:
    assert (
        check(
            "sentence", " i  PRACTICE english every day! ", ["I practice English every day."]
        ).result
        == "matched"
    )
    assert check("fill_blank", "Station", ["station"]).result == "matched"
    assert (
        check("sentence_order", "How today are you?", ["How are you today?"]).result
        == "needs_revision"
    )
    paragraph = check("paragraph", "i like parks", [])
    assert paragraph.result == "self_review"
    assert len(paragraph.suggestions) >= 2
