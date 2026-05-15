# lib/features/fb/backend/main.py
import os
from fastapi import FastAPI
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class SleepDataRequest(BaseModel):
    efficiency: str
    deep_time: str
    awakening_count: str
    memo: str

@app.post("/analyze_sleep")
async def analyze_sleep(req: SleepDataRequest):
    # AIへの依頼文（プロンプト）を作成
    prompt = f"""
    あなたは睡眠専門のAIアドバイザーです。以下の睡眠データを分析し、
    ユーザーが明日から改善できる具体的なアクションを150文字以内で提案してください。
    
    【昨夜のデータ】
    睡眠効率: {req.efficiency}
    深い睡眠時間: {req.deep_time}
    途中覚醒回数: {req.awakening_count}
    ユーザーのメモ: {req.memo}
    """

    # AIモデル（GPT-4oなど）で文章を生成
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}]
    )

    return {"ai_advice": response.choices[0].message.content}