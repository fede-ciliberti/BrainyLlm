import litellm
from litellm import CustomLLM
# from litellm.exceptions import CustomLLMError  # Import fails, define locally

class CustomLLMError(Exception):
    """Custom exception for LLM errors."""
    def __init__(self, status_code: int = 500, message: str = ""):
        self.status_code = status_code
        self.message = message
        super().__init__(self.message)
from litellm.types.utils import ModelResponse
import google.generativeai as genai
import os
from typing import Optional

class MyGeminiLLM(CustomLLM):
    def __init__(self):
        super().__init__()
        api_key = os.getenv("GEMINI_API_KEY_12")
        if not api_key:
            raise ValueError("GEMINI_API_KEY_12 not set")
        genai.configure(api_key=api_key)
        self.model = None  # Set in completion

    async def acompletion(
        self,
        *args,
        **kwargs
    ) -> ModelResponse:
        # Extract required params from kwargs
        model = kwargs.get("model")
        messages = kwargs.get("messages")
        if model is None or messages is None:
            raise CustomLLMError(status_code=500, message="Model and messages are required")

        # Extract optional params from kwargs
        temperature = kwargs.get("temperature", 0.7)
        top_p = kwargs.get("top_p", 0.95)
        top_k = kwargs.get("top_k", 1)
        max_tokens = kwargs.get("max_tokens", 1024)

        # Map OpenAI messages to Gemini contents
        contents = []
        system_prompt = ""
        for msg in messages:
            role = msg["role"]
            content = msg["content"]
            if role == "system":
                system_prompt += content + "\n"
            elif role == "user":
                parts = [{"text": content}]
                if system_prompt:
                    parts[0]["text"] = system_prompt + parts[0]["text"]
                    system_prompt = ""
                contents.append({"role": "user", "parts": parts})
            elif role == "assistant":
                contents.append({"role": "model", "parts": [{"text": content}]})

        if system_prompt and not contents:
            contents.append({"role": "user", "parts": [{"text": system_prompt}]})

        # Generation config
        generation_config = {
            "temperature": temperature or 0.7,
            "top_p": top_p or 0.95,
            "top_k": top_k or 1,
            "max_output_tokens": max_tokens or 1024,
        }

        try:
            # Generate
            internal_model = model.replace("custom_gemini/", "models/")
            gemini_model = genai.GenerativeModel(internal_model)
            response = await gemini_model.generate_content_async(
                contents, generation_config=genai.GenerationConfig(**generation_config), stream=False
            )

            text = response.text
            return ModelResponse(
                id="gemini-chat",
                choices=[
                    {
                        "message": {"role": "assistant", "content": text},
                        "finish_reason": "stop",
                        "index": 0,
                    }
                ],
                created=1,
                model=model,
                usage={
                    "prompt_tokens": len(contents),
                    "completion_tokens": len(text.split()),
                    "total_tokens": 0,
                },
            )
        except Exception as e:
            raise CustomLLMError(status_code=500, message=f"Gemini generation failed: {str(e)}")

my_gemini_llm = MyGeminiLLM()