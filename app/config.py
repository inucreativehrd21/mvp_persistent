"""
프로젝트 환경 설정 관리
.env 파일에서 환경변수를 읽어와서 설정합니다.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# .env 파일 로드
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=env_path)


class Config:
    """프로젝트 설정 클래스"""

    # 프로젝트 루트 경로
    PROJECT_ROOT = Path(__file__).parent.parent.absolute()

    # 데이터 경로
    DATA_FILE_PATH = Path(os.getenv(
        'DATA_FILE_PATH',
        PROJECT_ROOT / 'data' / 'problems_multi_solution.json'
    ))

    # vLLM 서버 설정
    VLLM_SERVER_URL = os.getenv('VLLM_SERVER_URL', 'http://localhost:8000/v1')
    VLLM_MODEL = os.getenv('VLLM_MODEL', 'Qwen/Qwen2.5-Coder-7B-Instruct')

    # Gradio 서버 설정
    GRADIO_PORT = int(os.getenv('GRADIO_PORT', '7860'))
    GRADIO_HOST = os.getenv('GRADIO_HOST', '127.0.0.1')

    # 로그 설정
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FILE_PATH = Path(os.getenv(
        'LOG_FILE_PATH',
        PROJECT_ROOT / 'logs' / 'app.log'
    ))

    @classmethod
    def create_directories(cls):
        """필요한 디렉토리 생성"""
        for directory in [cls.LOG_FILE_PATH.parent, cls.DATA_FILE_PATH.parent]:
            directory.mkdir(parents=True, exist_ok=True)

    @classmethod
    def print_config(cls):
        """현재 설정 출력"""
        print("=" * 60)
        print("프로젝트 환경 설정")
        print("=" * 60)
        print(f"프로젝트 루트: {cls.PROJECT_ROOT}")
        print(f"데이터 파일: {cls.DATA_FILE_PATH.relative_to(cls.PROJECT_ROOT)}")
        print(f"vLLM 서버: {cls.VLLM_SERVER_URL}")
        print(f"vLLM 모델: {cls.VLLM_MODEL}")
        print(f"Gradio 서버: {cls.GRADIO_HOST}:{cls.GRADIO_PORT}")
        print("=" * 60)


# 앱 시작 시 필요한 디렉토리 생성
Config.create_directories()
