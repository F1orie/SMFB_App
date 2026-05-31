from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import requests


class GeminiClient:
    def __init__(self) -> None:
        self._api_key = _load_api_key()
        self._model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        self._timeout_sec = float(os.getenv("GEMINI_TIMEOUT_SEC", "45"))
        self._max_output_tokens = int(os.getenv("GEMINI_MAX_OUTPUT_TOKENS", "4096"))

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
                "generationConfig": {"maxOutputTokens": self._max_output_tokens},
            },
            timeout=self._timeout_sec,
        )
        response.raise_for_status()
        return _strip_markdown(_extract_text(response.json()))


def _load_api_key() -> str | None:
    env_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if env_key:
        return env_key

    config_path = (
        Path(__file__).resolve().parents[2]
        / "application"
        / "config"
        / "analysis_config.dart"
    )
    if not config_path.exists():
        return None

    config_text = config_path.read_text(encoding="utf-8")
    match = re.search(r"geminiApiKey\s*=\s*'([^']+)'", config_text)
    if not match:
        return None

    api_key = match.group(1).strip()
    if not api_key or "ここに" in api_key or "YOUR_" in api_key:
        return None
    return api_key


def _extract_text(data: dict[str, Any]) -> str:
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini response has no candidates")
    candidate = candidates[0]
    finish_reason = candidate.get("finishReason")
    content = candidate.get("content") or {}
    parts = content.get("parts") or []
    text_parts = [str(part["text"]) for part in parts if "text" in part]
    if not text_parts:
        raise RuntimeError("Gemini response has no text part")
    if finish_reason == "MAX_TOKENS":
        raise RuntimeError("Gemini response was truncated by maxOutputTokens")
    return "".join(text_parts)


def _strip_markdown(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"\*(.+?)\*", r"\1", text)
    text = re.sub(r"#+\s", "", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    return text.strip()
