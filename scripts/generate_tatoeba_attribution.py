"""Regenerate attribution for the public Tatoeba API contract fixture."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
fixture = json.loads(
    (ROOT / "supabase/functions/_shared/fixtures/tatoeba-coffee-v1.json").read_text(
        encoding="utf-8"
    )
)
lines = [
    "# Ghi công mẫu kiểm thử Tatoeba",
    "",
    "Mẫu `tatoeba-coffee-v1.json` lấy từ Tatoeba API v1 ngày 11/11/2026. "
    "Chỉ dùng để kiểm thử hợp đồng. Mỗi câu giữ ID, tác giả và giấy phép trong JSON. "
    "Giấy phép: [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/deed.en) "
    "hoặc [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).",
    "",
    "| Câu Anh | Tác giả / giấy phép | Bản dịch Việt | Tác giả / giấy phép |",
    "|---|---|---|---|",
]
for sentence in fixture["data"]:
    for translation in sentence["translations"]:
        english_id = sentence["id"]
        vietnamese_id = translation["id"]
        lines.append(
            f"| [#{english_id}](https://tatoeba.org/en/sentences/show/{english_id}) "
            f"| {sentence.get('owner') or 'orphan'} / {sentence.get('license')} "
            f"| [#{vietnamese_id}](https://tatoeba.org/en/sentences/show/{vietnamese_id}) "
            f"| {translation.get('owner') or 'orphan'} / {translation.get('license')} |"
        )
(ROOT / "docs/TATOEBA_FIXTURE_ATTRIBUTION.md").write_text(
    "\n".join(lines) + "\n", encoding="utf-8"
)
