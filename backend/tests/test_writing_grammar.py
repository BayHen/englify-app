import asyncio

import httpx

from app.writing import grammar


def test_languagetool_response_contract(monkeypatch) -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.method == "POST"
        assert request.url.path == "/v2/check"
        assert b"language=en-US" in request.content
        return httpx.Response(
            200,
            json={
                "matches": [
                    {
                        "message": "Possible typo",
                        "offset": 2,
                        "length": 4,
                        "replacements": [{"value": "word"}],
                    }
                ]
            },
        )

    original_client = httpx.AsyncClient
    monkeypatch.setattr(
        grammar.httpx,
        "AsyncClient",
        lambda **kwargs: original_client(transport=httpx.MockTransport(respond), **kwargs),
    )
    result = asyncio.run(grammar.LanguageToolProvider("http://127.0.0.1:8082").check("a wrod"))
    assert result[0].message == "Possible typo"
    assert result[0].replacements == ("word",)
