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

`.env` 파일을 편집하여 필요한 설정을 조정하세요현

---

**마지막 업데이트:** 2025-11-05
**버전:** 3.0.0 (Docker Persistent 전용)
