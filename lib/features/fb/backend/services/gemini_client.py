from __future__ import annotations

import os
import re
from typing import Any

import requests


class GeminiClient:
    def __init__(self) -> None:
        self._api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        self._model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        self._timeout_sec = float(os.getenv("GEMINI_TIMEOUT_SEC", "45"))

    def generate(self, *, system_prompt: str, user_prompt: str) -> str:
        if not self._api_key:
            raise RuntimeError("GEMINI_API_KEY or GOOGLE_API_KEY is not set")

        endpoint = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self._model}:generateContent?key={self._api_key}"
        )
        response = requests.post(
            endpoint,
            json={
                "system_instruction": {"parts": [{"text": system_prompt}]},
                "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
                "generationConfig": {"maxOutputTokens": 1500},
            },
            timeout=self._timeout_sec,
        )
        response.raise_for_status()
        return _strip_markdown(_extract_text(response.json()))


def _extract_text(data: dict[str, Any]) -> str:
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini response has no candidates")
    content = candidates[0].get("content") or {}
    parts = content.get("parts") or []
    if not parts or "text" not in parts[0]:
        raise RuntimeError("Gemini response has no text part")
    return str(parts[0]["text"])


def _strip_markdown(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"\*(.+?)\*", r"\1", text)
    text = re.sub(r"#+\s", "", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    return text.strip()
