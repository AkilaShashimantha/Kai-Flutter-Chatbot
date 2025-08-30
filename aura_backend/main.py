import os
import uuid
import re
from pathlib import Path
from typing import Optional, Dict, List

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

# Load environment variables from .env next to this file
ENV_PATH = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=ENV_PATH)

# Also allow environment to override
OPENROUTER_API_KEY: Optional[str] = os.getenv("OPENROUTER_API_KEY")

app = FastAPI(title="Kai Backend", version="0.1.0")

# In-memory conversation storage: conversation_id -> list of messages
SESSIONS: Dict[str, List] = {}

# Enable CORS (useful for testing and Flutter web; harmless for mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, description="User's input message")
    conversation_id: Optional[str] = Field(None, description="Conversation identifier for multi-turn context")


class ChatResponse(BaseModel):
    reply: str
    conversation_id: str


# System prompt for Kai (domain-limited to wellbeing; no greetings; one question per message; no stickers)
AURA_SYSTEM_PROMPT = (
    """You are 'Kai,' a calm, kind friend who helps people feel better and find simple next steps.

Scope and refusal policy:
- ONLY support topics about stress, feelings, mood, anxiety, burnout, relationships, grief/loss, sleep, coping skills, self-care, and physical symptoms or illnesses that affect wellbeing.
- If the user asks for anything outside this scope (e.g., coding/tech, math, homework, shopping, weather, sports, news, politics, finance, general knowledge), politely decline that request and redirect to their wellbeing.
- When declining, be brief. Do NOT answer the off-topic question. Invite them to share how they're feeling or what's stressing them.

Greeting rules:
- Do NOT greet or use salutations (no 'Hi', 'Hello', 'Hey', or time-of-day greetings). Start directly with empathetic, warm content.

Conversation rules before solutions:
- Ask ONE short, gentle question at a time. One question per message. Wait for the user's answer before asking another.
- Use very simple English. Short sentences. Warm and caring.
- Keep a soothing, hopeful tone. You may use a few supportive emojis.
- Keep replies under 120 words.
- You are not a therapist. For crisis or self-harm, gently suggest contacting a professional or a local helpline.

When you are ready to give solutions:
- Offer the best, practical steps in simple English.
- Keep it brief and clear.

Do NOT include stickers or image links.
"""
)


def _strip_leading_greeting(text: str) -> str:
    """Remove leading greeting phrases (e.g., 'Hi', 'Hello', 'Hey there', 'Good morning').
    Applies only to the start of the text and can strip multiple greeting segments.
    """
    if not text:
        return text
    t = text.lstrip()
    pattern = re.compile(
        r"^(hey(?: there)?|hi(?: there)?|hello(?: there)?|greetings|howdy|yo|hiya|good\s*(?:morning|afternoon|evening|night|day))\s*[!,.:]*\s*",
        re.IGNORECASE,
    )
    # Strip up to 3 greeting segments at the very beginning
    for _ in range(3):
        m = pattern.match(t)
        if not m:
            break
        t = t[m.end():].lstrip()
    return t

# Configure the LLM client for OpenRouter with the specified model
# Note: Requires OPENROUTER_API_KEY in environment variables
if not OPENROUTER_API_KEY:
    # Do not fail on import; raise a clear error when the endpoint is called
    pass


@app.get("/")
def root():
    return {"message": "Kai backend is running. POST to /chat with {'message': '...'}"}


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(payload: ChatRequest) -> ChatResponse:
    # Ensure latest env is loaded, so users can update .env without restart
    load_dotenv(dotenv_path=ENV_PATH, override=False)
    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        raise HTTPException(status_code=500, detail="Server is not configured with OPENROUTER_API_KEY.")

    try:
        llm = ChatOpenAI(
            model="google/gemini-flash-1.5",
            base_url="https://openrouter.ai/api/v1",
            api_key=key,
            temperature=0.6,
            max_tokens=350,
        )

        # Provide current local time context for time-of-day greeting
        from datetime import datetime
        now = datetime.now()
        time_context = (
            f"Current local datetime: {now.isoformat(timespec='minutes')} | hour24={now.hour}"
        )

        # Resolve conversation id and history
        cid = payload.conversation_id or str(uuid.uuid4())
        history = SESSIONS.get(cid, [])

        # Determine if this is the first reply in the conversation
        is_first_reply = len(history) == 0

        # Enforce no greetings at any time
        greeting_control = (
            "GLOBAL POLICY: Do NOT greet or use salutations like 'Hi', 'Hello', 'Hey', or time-of-day greetings. Start directly with empathetic content."
        )

        messages = [
            SystemMessage(content=time_context),
            SystemMessage(content=AURA_SYSTEM_PROMPT),
            SystemMessage(content=greeting_control),
            *history,
            HumanMessage(content=payload.message),
        ]
        result = llm.invoke(messages)
        reply_text = result.content if hasattr(result, "content") else str(result)

        # Remove any leading greeting phrases from the model's reply
        reply_text = _strip_leading_greeting(reply_text)

        # Update history and keep it bounded
        history.extend([HumanMessage(content=payload.message), AIMessage(content=reply_text)])
        if len(history) > 16:
            history = history[-16:]
        SESSIONS[cid] = history

        return ChatResponse(reply=reply_text, conversation_id=cid)
    except Exception as e:
        # Basic error handling for the LLM API call
        raise HTTPException(status_code=502, detail=f"Upstream model error: {e}")
