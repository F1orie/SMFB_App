from __future__ import annotations

import json
from pathlib import Path
from typing import Any


PROMPT_KEYS = {
    "bedding": "bedding_advice",
    "food": "food_advice",
    "routine": "routine_advice",
    "chat": "chat",
}


class PromptBuilder:
    def __init__(self, prompt_path: Path | None = None) -> None:
        self._prompt_path = prompt_path or Path(__file__).resolve().parents[1] / "prompts" / "fb_prompts.json"
        self._config = self._load_config()

    @property
    def version(self) -> str:
        return str(self._config.get("version", "1.0"))

    def build(
        self,
        *,
        advice_type: str,
        query: str,
        sleep_summary: str,
        product_suggestions: str,
        chat_history: list[dict[str, str]],
    ) -> tuple[str, str]:
        prompt_key = PROMPT_KEYS.get(advice_type, "chat")
        prompt = self._config["prompts"][prompt_key]
        values = {
            "sleep_summary": sleep_summary,
            "product_suggestions": product_suggestions,
            "query": query,
            "chat_history": _format_chat_history(chat_history),
        }
        return prompt["system"], prompt["user_template"].format_map(_SafeValues(values))

    def _load_config(self) -> dict[str, Any]:
        with self._prompt_path.open("r", encoding="utf-8") as file:
            return json.load(file)


class _SafeValues(dict[str, str]):
    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


def _format_chat_history(chat_history: list[dict[str, str]]) -> str:
    if not chat_history:
        return "履歴なし"

    lines = []
    for message in chat_history[-10:]:
        role = "ユーザー" if message.get("role") == "user" else "アシスタント"
        content = message.get("content", "")
        lines.append(f"{role}: {content}")
    return "\n".join(lines)
