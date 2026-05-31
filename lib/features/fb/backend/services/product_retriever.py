from __future__ import annotations

import re
from dataclasses import dataclass

from .product_pdf_loader import ProductDocument


@dataclass(frozen=True)
class ProductSuggestion:
    source: str
    excerpt: str
    score: int


ADVICE_TYPE_KEYWORDS = {
    "bedding": ["寝具", "枕", "まくら", "マットレス", "布団", "ふとん", "シーツ"],
    "food": ["食品", "食べ物", "飲み物", "夕食", "カフェイン", "温かい", "栄養"],
    "routine": [
        "入浴",
        "ストレッチ",
        "ルーティン",
        "照明",
        "リラックス",
        "運動",
        "就寝",
        "寝る前",
        "習慣",
        "呼吸",
        "スマホ",
        "起床",
    ],
    "chat": ["睡眠", "改善", "眠り", "寝る", "起床"],
}


def retrieve_products(
    documents: tuple[ProductDocument, ...],
    query: str,
    advice_type: str,
    limit: int = 1,
) -> list[ProductSuggestion]:
    if not documents:
        return []

    query_terms = _tokenize(query)
    type_terms = ADVICE_TYPE_KEYWORDS.get(advice_type, ADVICE_TYPE_KEYWORDS["chat"])
    terms = set(query_terms + type_terms)
    scored: list[ProductSuggestion] = []

    for document in documents:
        normalized_text = document.text.lower()
        score = sum(normalized_text.count(term.lower()) for term in terms if term)
        if score <= 0:
            continue
        scored.append(
            ProductSuggestion(
                source=document.source,
                excerpt=_best_excerpt(document.text, terms),
                score=score,
            )
        )

    return sorted(scored, key=lambda item: item.score, reverse=True)[:limit]


def format_product_suggestions(suggestions: list[ProductSuggestion]) -> str:
    if not suggestions:
        return "該当する商品PDF候補はありません。商品名を無理に挙げず、一般的な改善提案に留めてください。"

    lines = []
    for index, suggestion in enumerate(suggestions, start=1):
        lines.append(
            f"{index}. 出典PDF: {suggestion.source}\n"
            f"   関連抜粋: {suggestion.excerpt}"
        )
    return "\n".join(lines)


def _tokenize(text: str) -> list[str]:
    return [
        term
        for term in re.split(r"[\s　、。,.!！?？:：;；()\[\]「」『』]+", text)
        if len(term) >= 2
    ]


def _best_excerpt(text: str, terms: set[str], max_length: int = 220) -> str:
    compact = re.sub(r"\s+", " ", text).strip()
    if len(compact) <= max_length:
        return _remove_price_text(compact)

    lower = compact.lower()
    positions = [lower.find(term.lower()) for term in terms if term and lower.find(term.lower()) >= 0]
    start = max(0, min(positions) - 40) if positions else 0
    excerpt = compact[start : start + max_length]
    return _remove_price_text(excerpt.strip())


def _remove_price_text(text: str) -> str:
    text = re.sub(r"価格（?税込）?", "", text)
    text = re.sub(r"[¥￥]\s?[\d,]+", "", text)
    return re.sub(r"\s{2,}", " ", text).strip()
