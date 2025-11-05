"""
vLLM 모델 설정
"""

# 지원 모델 목록
VLLM_MODELS = {
    "qwen-7b": {
        "name": "Qwen/Qwen2.5-Coder-7B-Instruct",
        "max_tokens": 4096,
        "context_length": 32768,
        "estimated_vram": "8GB",
        "description": "가장 추천되는 코딩 모델 (속도/성능 밸런스)",
    },
    "deepseek-7b": {
        "name": "deepseek-ai/deepseek-coder-7b-instruct-v1.5",
        "max_tokens": 4096,
        "context_length": 16384,
        "estimated_vram": "8GB",
        "description": "코딩 특화 모델",
    },
    "codellama-7b": {
        "name": "codellama/CodeLlama-7b-Instruct-hf",
        "max_tokens": 4096,
        "context_length": 16384,
        "estimated_vram": "8GB",
        "description": "Meta 공식 코딩 모델",
    },
    "qwen-14b": {
        "name": "Qwen/Qwen2.5-Coder-14B-Instruct",
        "max_tokens": 4096,
        "context_length": 32768,
        "estimated_vram": "18GB",
        "description": "고성능 코딩 모델 (16GB+ VRAM 권장)",
    },
}

# 생성 파라미터 기본값
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "max_tokens": 512,
    "frequency_penalty": 0.3,
    "presence_penalty": 0.1,
}

# vLLM 서버 설정
VLLM_SERVER_CONFIG = {
    "default_url": "http://localhost:8000/v1",
    "timeout": 60,
    "max_retries": 3,
}
