# vLLM 백준 힌트 생성 시스템

소크라테스 학습법 기반 코딩 힌트 제공 시스템

## 프로젝트 소개

사용자가 작성한 코드를 분석하여 **직접 답을 알려주지 않고** 스스로 생각하도록 유도하는 소크라테스식 힌트를 제공합니다.

**주요 기능:**
- 백준 문제 529개 지원
- vLLM 고속 추론 (15~20배 빠름)
- 다중 풀이 방법 지원
- Temperature 조절로 창의성 제어

---

## 기술 스택

- **vLLM**: 고속 LLM 추론 엔진 (15~20배 빠름)
- **Gradio**: 웹 UI 프레임워크
- **Docker**: 컨테이너화
- **OpenAI API**: vLLM 서버와 통신
- **RunPod**: GPU 클라우드 플랫폼

**지원 모델:**
- Qwen/Qwen2.5-Coder-7B-Instruct (권장)
- deepseek-ai/deepseek-coder-7b-instruct-v1.5
- codellama/CodeLlama-7b-Instruct-hf

---

## 빠른 시작

### 1. 사전 요구사항

- Docker & Docker Compose
- NVIDIA GPU (8GB+ VRAM 권장)
- NVIDIA Container Toolkit

### 2. 설치

```bash
git clone <your-repo>
cd final_project
cp .env.example .env
```

### 3. 환경 변수 설정

`.env` 파일을 편집하여 필요한 설정을 조정하세요:

```env
# vLLM 설정
VLLM_MODEL=Qwen/Qwen2.5-Coder-7B-Instruct
VLLM_PORT=8000
VLLM_SERVER_URL=http://localhost:8000/v1

# Gradio 설정
GRADIO_PORT=7860
GRADIO_HOST=0.0.0.0

# HuggingFace
HUGGINGFACE_CACHE_DIR=~/.cache/huggingface
HUGGING_FACE_HUB_TOKEN=  # Private 모델 사용 시만 필요
```

### 4. 실행

**Linux/Mac:**
```bash
./start_server.sh    # vLLM Docker 서버 시작
./start_client.sh    # Gradio 클라이언트 시작
```

**Windows:**
```batch
start_server.bat    # vLLM Docker 서버 시작
start_client.bat    # Gradio 클라이언트 시작
```

### 5. 접속

브라우저에서 `http://localhost:7860` 접속

---

## 프로젝트 구조

```
final_project/
├── docker-compose.yml         # vLLM 서버 설정
├── .env.example               # 환경 변수 예시
├── start_server.sh/bat        # 서버 시작 스크립트
├── start_client.sh/bat        # 클라이언트 시작 스크립트
├── app/
│   ├── app.py                 # Gradio UI
│   ├── config.py              # 설정 관리
│   ├── requirements.txt       # Python 의존성
│   └── models/
│       ├── model_config.py    # 모델 설정
│       └── model_inference.py # vLLM 추론 엔진
├── data/
│   └── problems_multi_solution.json  # 백준 문제 데이터
└── logs/                      # 애플리케이션 로그
```

---

## 주요 기능

### 1. 소크라테스 학습법

직접 답을 주지 않고 학생이 스스로 생각하게 유도

**예시:**
```
❌ 나쁜 힌트: "def 키워드로 함수를 정의하세요"
✅ 좋은 힌트: "이 계산을 100번 반복해야 한다면 코드를 복사할 건가요?"
```

### 2. Temperature 조절

힌트의 창의성 제어

- **0.1~0.3:** 일관적, 보수적
- **0.5~0.7:** 균형 (권장)
- **0.8~1.0:** 창의적, 다양

### 3. 다중 모델 지원

상황에 따라 다양한 코딩 모델 선택 가능

---

## RunPod 배포 가이드

RunPod Pod에서 Docker로 배포하는 방법은 [RUNPOD_POD_DEPLOYMENT.md](RUNPOD_POD_DEPLOYMENT.md)를 참고하세요.

**특징:**
- 항상 실행 (Persistent)
- 즉시 응답 (< 1초)
- 안정적 성능
- 완전한 제어

---

## 환경 변수 설명

### vLLM 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `VLLM_MODEL` | `Qwen/Qwen2.5-Coder-7B-Instruct` | 사용할 모델 |
| `VLLM_PORT` | `8000` | vLLM 서버 포트 |
| `VLLM_SERVER_URL` | `http://localhost:8000/v1` | vLLM 서버 URL |
| `MAX_MODEL_LEN` | `4096` | 최대 컨텍스트 길이 |
| `GPU_MEMORY_UTIL` | `0.9` | GPU 메모리 사용률 (0.0-1.0) |

### Gradio 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `GRADIO_PORT` | `7860` | Gradio 웹 UI 포트 |
| `GRADIO_HOST` | `0.0.0.0` | Gradio 호스트 (0.0.0.0 = 외부 접속 허용) |

### HuggingFace 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `HUGGINGFACE_CACHE_DIR` | `~/.cache/huggingface` | 모델 캐시 디렉토리 |
| `HUGGING_FACE_HUB_TOKEN` | (선택) | Private 모델 접근 토큰 |

---

## 성능 벤치마크

### RTX 3090 기준

```
모델: Qwen 7B
추론 속도: ~80 tokens/sec
응답 시간: < 1초
메모리: 14GB VRAM
비용: $0.24/시간 (RunPod)
```

### RTX 4090 기준

```
모델: Qwen 7B
추론 속도: ~120 tokens/sec
응답 시간: < 0.5초
메모리: 14GB VRAM
비용: $0.40/시간 (RunPod)
```

---

## 비용 예상 (RunPod 기준)

### 24시간 실행

```
RTX 3090: $0.24/시간 × 24 = $5.76/일 = $172.80/월
RTX 4090: $0.40/시간 × 24 = $9.60/일 = $288/월
```

### 비용 최적화 팁

1. **필요할 때만 실행**: Pod를 중지하면 스토리지 비용만 발생 ($0.02/GB/월)
2. **적절한 GPU 선택**: RTX 3090이 가성비 최고
3. **모델 크기 조절**: 7B 모델이 성능/비용 균형 최적

---

## 문제 해결

### vLLM 서버가 시작되지 않음

```bash
# Docker 로그 확인
docker logs vllm-hint-server

# GPU 확인
nvidia-smi

# Docker Compose 재시작
docker-compose down
docker-compose up -d
```

### Gradio 연결 실패

1. vLLM 서버가 실행 중인지 확인
2. `.env` 파일의 `VLLM_SERVER_URL` 확인
3. 포트 충돌 확인

### CUDA/GPU 오류

```bash
# NVIDIA Container Toolkit 설치 확인
nvidia-container-cli info

# Docker에서 GPU 접근 확인
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### 메모리 부족 오류

1. `.env`에서 `GPU_MEMORY_UTIL` 값을 0.8로 낮추기
2. 더 작은 모델 사용 (7B → 3B)
3. `MAX_MODEL_LEN` 값 줄이기

---

## 모델 변경 방법

1. `.env` 파일 수정:
```env
VLLM_MODEL=deepseek-ai/deepseek-coder-7b-instruct-v1.5
```

2. Docker 재시작:
```bash
docker-compose down
docker-compose up -d
```

3. 클라이언트 재시작:
```bash
./start_client.sh
```

---

## 개발자 가이드

### 로컬 개발 환경 설정

```bash
# 가상환경 생성
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
cd app
pip install -r requirements.txt

# 개발 모드 실행
python app.py
```

### 코드 구조

- `app/app.py`: Gradio UI 및 메인 애플리케이션 로직
- `app/config.py`: 환경 변수 및 설정 관리
- `app/models/model_inference.py`: vLLM 추론 엔진
- `app/models/model_config.py`: 모델 메타데이터

---

## 참고 자료

- [vLLM 공식 문서](https://docs.vllm.ai/)
- [RunPod 문서](https://docs.runpod.io/)
- [Gradio 문서](https://www.gradio.app/docs/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

---

## 라이선스

Educational use only

## 기여자

Team 5 - PlayData AI 부트캠프

---

**마지막 업데이트:** 2025-11-05
**버전:** 3.0.0 (Docker Persistent 전용)
