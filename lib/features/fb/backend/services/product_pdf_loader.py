from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


@dataclass(frozen=True)
class ProductDocument:
    source: str
    text: str


def default_product_dir() -> Path:
    project_root = Path(__file__).resolve().parents[5]
    return project_root / "data" / "products"


@lru_cache(maxsize=1)
def load_product_documents(product_dir: str | None = None) -> tuple[ProductDocument, ...]:
    root = Path(product_dir) if product_dir else default_product_dir()
    if not root.exists():
        return ()

    documents: list[ProductDocument] = []
    for pdf_path in sorted(root.glob("*.pdf")):
        text = _extract_pdf_text(pdf_path).strip()
        if text:
            documents.append(ProductDocument(source=pdf_path.name, text=text))
    return tuple(documents)


def _extract_pdf_text(pdf_path: Path) -> str:
    try:
        from pypdf import PdfReader
    except ImportError:
        return ""

    try:
        reader = PdfReader(str(pdf_path))
        return "\n".join(page.extract_text() or "" for page in reader.pages)
    except Exception:
        return ""
