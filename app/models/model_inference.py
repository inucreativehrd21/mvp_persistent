"""
vLLM 서버와 통신하는 추론 클래스
"""
import time
from typing import Dict, Optional
from openai import OpenAI


class VLLMInference:
    """
    vLLM OpenAI 호환 API 기반 추론

    Docker로 실행되는 vLLM 서버와 통신하여 힌트를 생성합니다.
    """

    def __init__(
        self,
        model_name: str,
        base_url: str = "http://localhost:8000/v1",
        timeout: int = 60,
        max_retries: int = 3
    ):
        self.model_name = model_name
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = max_retries

        self.client = OpenAI(
            base_url=base_url,
            api_key="dummy",  # vLLM은 API key 불필요
            timeout=timeout,
            max_retries=max_retries
        )

        self._check_server_health()

    def _check_server_health(self) -> bool:
        """vLLM 서버 연결 확인"""
        try:
            models = self.client.models.list()
            available_models = [model.id for model in models.data]

            if available_models:
                print(f"✅ vLLM 서버 연결 성공: {self.base_url}")
                print(f"   사용 가능한 모델: {', '.join(available_models)}")

                if self.model_name not in available_models:
                    old_name = self.model_name
                    self.model_name = available_models[0]
                    print(f"⚠️  모델 '{old_name}'을 찾을 수 없어 '{self.model_name}' 사용")

                return True
            else:
                print(f"⚠️  vLLM 서버에 로드된 모델이 없습니다: {self.base_url}")
                return False

        except Exception as e:
            print(f"❌ vLLM 서버 연결 실패: {self.base_url}")
            print(f"   오류: {e}")
            print("   docker-compose up으로 서버를 시작해주세요.")
            return False

    def generate_hint(
        self,
        prompt: str,
        max_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        frequency_penalty: float = 0.0,
        presence_penalty: float = 0.0,
        system_prompt: Optional[str] = None
    ) -> Dict:
        """
        힌트 생성

        Args:
            prompt: 사용자 프롬프트
            max_tokens: 최대 생성 토큰 수
            temperature: 샘플링 온도 (0.0-2.0)
            top_p: Nucleus sampling threshold
            frequency_penalty: 반복 억제 (-2.0 ~ 2.0)
            presence_penalty: 주제 다양성 (-2.0 ~ 2.0)
            system_prompt: 시스템 프롬프트

        Returns:
            {
                'hint': str,
                'time': float,
                'model': str,
                'error': str,
                'tokens': int,
                'finish_reason': str
            }
        """
        if system_prompt is None:
            system_prompt = """당신은 소크라테스식 프로그래밍 멘토입니다.
학생에게 직접적인 답을 주지 말고, 스스로 생각하고 발견하도록 질문과 힌트를 제공하세요.
절대로 코드의 함수명, 변수명을 직접 언급하지 마세요."""

        try:
            start_time = time.time()

            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                frequency_penalty=frequency_penalty,
                presence_penalty=presence_penalty,
                n=1,
                stream=False
            )

            hint = response.choices[0].message.content.strip()
            elapsed = time.time() - start_time
            tokens_used = response.usage.completion_tokens if response.usage else 0
            finish_reason = response.choices[0].finish_reason

            return {
                'hint': hint,
                'time': elapsed,
                'model': self.model_name,
                'error': None,
                'tokens': tokens_used,
                'finish_reason': finish_reason
            }

        except Exception as e:
            elapsed = time.time() - start_time
            error_msg = str(e)

            if "Connection" in error_msg or "timeout" in error_msg.lower():
                error_msg = f"vLLM 서버 연결 실패 ({self.base_url}). docker-compose up으로 서버를 시작해주세요."
            elif "model" in error_msg.lower():
                error_msg = f"모델 '{self.model_name}'를 찾을 수 없습니다. docker-compose.yml의 VLLM_MODEL을 확인하세요."

            print(f"❌ VLLMInference 오류: {error_msg}")

            return {
                'hint': '',
                'time': elapsed,
                'model': self.model_name,
                'error': error_msg,
                'tokens': 0,
                'finish_reason': 'error'
            }
