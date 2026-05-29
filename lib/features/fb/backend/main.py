from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .services.gemini_client import GeminiClient
from .services.product_pdf_loader import load_product_documents
from .services.product_retriever import format_product_suggestions, retrieve_products
from .services.prompt_builder import PromptBuilder
from .services.sleep_summarizer import summarize_sleep_data

load_dotenv()

app = FastAPI(title="SMF RAG Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

prompt_builder = PromptBuilder()
gemini_client = GeminiClient()


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class RagAnalyzeRequest(BaseModel):
    query: str
    advice_type: Literal["bedding", "food", "routine", "chat"]
    payload_version: str
    sleep_data_source: Literal["sqlite", "existing_repository_fallback"]
    sleep_data: dict[str, Any] = Field(default_factory=dict)
    chat_history: list[ChatMessage] = Field(default_factory=list)


class RagAnalyzeResponse(BaseModel):
    text: str
    confidence: float
    created_at: str


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "prompt_version": prompt_builder.version}


@app.post("/rag_analyze", response_model=RagAnalyzeResponse)
async def rag_analyze(req: RagAnalyzeRequest) -> RagAnalyzeResponse:
    sleep_summary = summarize_sleep_data(req.sleep_data, req.sleep_data_source)
    product_documents = load_product_documents()
    product_suggestions = retrieve_products(
        product_documents,
        req.query,
        req.advice_type,
    )
    product_suggestion_text = format_product_suggestions(product_suggestions)
    system_prompt, user_prompt = prompt_builder.build(
        advice_type=req.advice_type,
        query=req.query,
        sleep_summary=sleep_summary,
        product_suggestions=product_suggestion_text,
        chat_history=[_model_to_dict(message) for message in req.chat_history],
    )

    try:
        text = await run_in_threadpool(
            gemini_client.generate,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )
    except requests.HTTPError as error:
        status_code = error.response.status_code if error.response is not None else 502
        if status_code == 503:
            raise HTTPException(status_code=503, detail="Gemini is temporarily unavailable") from error
        raise HTTPException(status_code=502, detail=f"Gemini request failed: {error}") from error
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error

    confidence = 0.75 if product_suggestions else 0.65
    return RagAnalyzeResponse(
        text=text,
        confidence=confidence,
        created_at=datetime.now(timezone.utc).isoformat(),
    )


def _model_to_dict(model: BaseModel) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    return model.dict()