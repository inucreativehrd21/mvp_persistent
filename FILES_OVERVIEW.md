# 프로젝트 파일 구조 및 설명

## 📁 전체 구조

```
mvp_persistent/
├── 📄 README.md                       # 프로젝트 메인 문서
├── 📄 .env.example                    # 환경 변수 예시
├── 📄 .env                            # 환경 변수 (사용자가 생성)
│
├── 🐳 Docker 관련
│   ├── docker-compose.yml             # Docker Compose 설정 (로컬/일반 Pod)
│   └── docker-compose.podman.yml      # Podman Compose 설정 (Explore Pod)
│
├── 📖 문서
│   ├── README.md                      # 메인 문서
│   ├── QUICKSTART_RUNPOD.md          # 런팟 빠른 시작 (5분)
│   ├── RUNPOD_PODMAN_GUIDE.md        # 런팟 Podman 상세 가이드
│   ├── RUNPOD_POD_DEPLOYMENT.md      # 런팟 Docker 가이드
│   └── FILES_OVERVIEW.md             # 이 파일
│
├── 🚀 실행 스크립트
│   ├── setup_permissions.sh           # 스크립트 권한 일괄 설정
│   ├── install_podman.sh              # Podman 환경 자동 설치
│   ├── check_environment.sh           # 환경 검증
│   ├── start_server.sh/.bat           # vLLM 서버 시작 (Docker)
│   ├── start_server_podman.sh         # vLLM 서버 시작 (Podman)
│   ├── start_client.sh/.bat           # Gradio 클라이언트 시작
│   └── troubleshoot.sh                # 문제 해결 도구
│
├── 📂 app/                            # 애플리케이션 코드
│   ├── app.py                         # Gradio UI
│   ├── config.py                      # 설정 관리
│   ├── requirements.txt               # Python 의존성
│   └── models/
│       ├── model_config.py            # 모델 설정
│       └── model_inference.py         # vLLM 추론 엔진
│
├── 📂 data/                           # 데이터
│   └── problems_multi_solution.json   # 백준 문제 데이터
│
└── 📂 logs/                           # 로그 (자동 생성)
    └── app.log
```

---

## 📄 주요 파일 설명

### 1. 문서 파일

#### [README.md](README.md)
- 프로젝트 전체 소개
- 로컬 환경 빠른 시작
- 기술 스택, 기능 설명
- 모든 배포 방식 링크

#### [QUICKSTART_RUNPOD.md](QUICKSTART_RUNPOD.md) ⭐
- **가장 빠르게 시작하는 방법 (5분)**
- RunPod Explore Pod 환경 전용
- Podman 기반
- 단계별 명령어만 포함

#### [RUNPOD_PODMAN_GUIDE.md](RUNPOD_PODMAN_GUIDE.md)
- RunPod Explore Pod 상세 가이드
- Podman 설치부터 문제 해결까지
- 모든 명령어와 설명 포함

#### [RUNPOD_POD_DEPLOYMENT.md](RUNPOD_POD_DEPLOYMENT.md)
- RunPod 일반 Pod (Docker 데몬 있음)
- Docker & Docker Compose 사용
- 전통적인 Docker 방식

---

### 2. 설정 파일

#### [.env.example](.env.example)
- 환경 변수 템플릿
- 모든 설정 옵션과 설명 포함
- 사용자는 이를 복사하여 `.env` 생성

**사용법:**
```bash
cp .env.example .env
nano .env
```

#### [docker-compose.yml](docker-compose.yml)
- Docker Compose 설정
- 로컬 환경 및 RunPod 일반 Pod용
- `runtime: nvidia` 사용

#### [docker-compose.podman.yml](docker-compose.podman.yml)
- Podman Compose 설정
- RunPod Explore Pod 전용
- GPU 디바이스 직접 마운트 방식

---

### 3. 스크립트 파일

#### [setup_permissions.sh](setup_permissions.sh)
- **첫 실행:** 모든 스크립트에 실행 권한 부여
- 가장 먼저 실행해야 함

**사용법:**
```bash
chmod +x setup_permissions.sh
./setup_permissions.sh
```

#### [install_podman.sh](install_podman.sh) ⭐
- **Podman 환경 자동 설치**
- RunPod Explore Pod에서 필수
- 다음 항목 설치:
  - Podman
  - podman-compose
  - crun 런타임
  - nvidia-container-toolkit
  - NVIDIA CDI 설정

**사용법:**
```bash
./install_podman.sh
```

#### [check_environment.sh](check_environment.sh) ⭐
- **환경 검증 스크립트**
- 실행 전 문제 사전 감지
- GPU, Podman, 설정 파일 등 검증

**사용법:**
```bash
./check_environment.sh
```

**검증 항목:**
- GPU 및 VRAM
- Podman 설치
- podman-compose 설치
- nvidia-container-toolkit
- GPU 디바이스 파일
- 프로젝트 파일
- 포트 충돌
- Podman GPU 접근 테스트

#### [start_server.sh](start_server.sh) / [start_server.bat](start_server.bat)
- **vLLM Docker 서버 시작** (로컬/일반 Pod)
- `docker-compose.yml` 사용

**사용법:**
```bash
# Linux/Mac
./start_server.sh

# Windows
start_server.bat
```

#### [start_server_podman.sh](start_server_podman.sh) ⭐
- **vLLM Podman 서버 시작** (Explore Pod)
- `docker-compose.podman.yml` 사용
- RunPod Explore Pod 전용

**사용법:**
```bash
./start_server_podman.sh
```

#### [start_client.sh](start_client.sh) / [start_client.bat](start_client.bat)
- **Gradio 클라이언트 시작**
- 모든 환경에서 동일하게 사용

**사용법:**
```bash
# Linux/Mac
./start_client.sh

# Windows
start_client.bat
```

#### [troubleshoot.sh](troubleshoot.sh) ⭐
- **대화형 문제 해결 도구**
- 9가지 문제 시나리오 자동 진단 및 해결

**사용법:**
```bash
./troubleshoot.sh
```

**제공 기능:**
1. GPU 접근 오류 해결
2. 메모리 부족 (OOM) 해결
3. vLLM 서버 시작 실패 진단
4. Gradio 연결 실패 진단
5. 모델 다운로드 문제 해결
6. 포트 충돌 해결
7. 컨테이너 상태 확인
8. 전체 환경 재설정
9. 로그 수집

---

### 4. 애플리케이션 파일

#### [app/app.py](app/app.py)
- Gradio 웹 UI
- 메인 애플리케이션 로직

#### [app/config.py](app/config.py)
- 환경 변수 로드
- 설정 관리

#### [app/requirements.txt](app/requirements.txt)
- Python 의존성 목록

#### [app/models/model_inference.py](app/models/model_inference.py)
- vLLM 추론 엔진
- OpenAI API 클라이언트

#### [app/models/model_config.py](app/models/model_config.py)
- 모델 메타데이터

---

### 5. 데이터 파일

#### [data/problems_multi_solution.json](data/problems_multi_solution.json)
- 백준 문제 529개 데이터
- 문제, 풀이, 힌트 정보 포함

---

## 🚀 사용 시나리오별 파일 사용법

### 시나리오 1: RunPod Explore Pod에서 처음 시작 (가장 일반적) ⭐

```bash
# 1. 프로젝트 업로드
cd /workspace
git clone <repo> mvp_persistent
cd mvp_persistent

# 2. 스크립트 권한 설정
chmod +x setup_permissions.sh
./setup_permissions.sh

# 3. Podman 설치
./install_podman.sh

# 4. 환경 검증
./check_environment.sh

# 5. 환경 변수 설정
cp .env.example .env
nano .env

# 6. 서버 시작
./start_server_podman.sh

# 7. 클라이언트 시작 (새 터미널)
./start_client.sh
```

**사용 문서:**
- [QUICKSTART_RUNPOD.md](QUICKSTART_RUNPOD.md)

**사용 파일:**
- `install_podman.sh`
- `check_environment.sh`
- `docker-compose.podman.yml`
- `start_server_podman.sh`
- `start_client.sh`

---

### 시나리오 2: 로컬 환경 (Docker 있음)

```bash
# 1. 프로젝트 클론
git clone <repo>
cd mvp_persistent

# 2. 환경 변수 설정
cp .env.example .env
nano .env

# 3. 서버 시작 (Docker)
./start_server.sh
# 또는 Windows
start_server.bat

# 4. 클라이언트 시작
./start_client.sh
# 또는 Windows
start_client.bat
```

**사용 문서:**
- [README.md](README.md)

**사용 파일:**
- `docker-compose.yml`
- `start_server.sh` / `start_server.bat`
- `start_client.sh` / `start_client.bat`

---

### 시나리오 3: RunPod 일반 Pod (Docker 있음)

```bash
# 1. 프로젝트 업로드
cd /workspace
git clone <repo> mvp_persistent
cd mvp_persistent

# 2. 환경 변수 설정
cp .env.example .env
nano .env

# 3. 서버 시작 (Docker)
./start_server.sh

# 4. 클라이언트 시작
./start_client.sh
```

**사용 문서:**
- [RUNPOD_POD_DEPLOYMENT.md](RUNPOD_POD_DEPLOYMENT.md)

**사용 파일:**
- `docker-compose.yml`
- `start_server.sh`
- `start_client.sh`

---

## 🔧 문제 발생 시

### 1. 환경 검증
```bash
./check_environment.sh
```

### 2. 대화형 문제 해결
```bash
./troubleshoot.sh
```

### 3. 로그 확인
```bash
# Podman
podman logs -f vllm-hint-server

# Docker
docker logs -f vllm-hint-server

# Gradio
tail -f logs/app.log
```

---

## 📊 파일 중요도

| 중요도 | 파일 | 용도 |
|--------|------|------|
| ⭐⭐⭐ | `QUICKSTART_RUNPOD.md` | 런팟에서 빠른 시작 |
| ⭐⭐⭐ | `install_podman.sh` | Podman 환경 설치 |
| ⭐⭐⭐ | `start_server_podman.sh` | Podman 서버 시작 |
| ⭐⭐⭐ | `docker-compose.podman.yml` | Podman 설정 |
| ⭐⭐ | `check_environment.sh` | 환경 검증 |
| ⭐⭐ | `troubleshoot.sh` | 문제 해결 |
| ⭐⭐ | `start_client.sh` | 클라이언트 시작 |
| ⭐ | `setup_permissions.sh` | 권한 설정 |
| ⭐ | `RUNPOD_PODMAN_GUIDE.md` | 상세 가이드 |

---

## 🎯 핵심 요약

### RunPod Explore Pod (Docker 데몬 ❌)
1. `install_podman.sh` - 환경 설치
2. `check_environment.sh` - 검증
3. `start_server_podman.sh` - 서버 시작
4. `start_client.sh` - 클라이언트 시작

### 로컬/일반 Pod (Docker 데몬 ✅)
1. `start_server.sh` - 서버 시작
2. `start_client.sh` - 클라이언트 시작

### 문제 발생 시
1. `check_environment.sh` - 환경 검증
2. `troubleshoot.sh` - 문제 해결

---

**마지막 업데이트:** 2025-11-05
