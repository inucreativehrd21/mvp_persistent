# RunPod Pod + Docker 배포 가이드

**배포 방식:** RunPod Pod(인스턴스)를 생성하고 그 안에서 Docker로 vLLM 서버를 실행

## 🎯 이 방식이란?

```
RunPod Pod (GPU 인스턴스)
└── Docker Container (vLLM 서버)
    └── Qwen 7B 모델
```

**특징:**
- ✅ 항상 실행 중 (Persistent)
- ✅ 즉시 응답 (< 1초)
- ✅ Docker로 격리된 환경
- ✅ 완전한 제어권

**vs Serverless:**
- Serverless: RunPod이 모든 것 관리, 자동 확장
- Pod + Docker: 직접 관리, 고정 성능

---

## 📋 사전 준비

### 1. RunPod 계정
- [RunPod](https://www.runpod.io/) 가입
- 결제 수단 등록

### 2. 로컬 환경 (프로젝트 업로드용)
- Git 또는 파일 업로드 준비
- SSH 키 생성 (선택)

---

## 🚀 단계별 배포

### 1단계: RunPod Pod 생성

#### 1.1 RunPod 대시보드 접속
- **Pods** 메뉴 클릭
- **+ Deploy** 클릭

#### 1.2 GPU 선택
```
권장 GPU (모델별):
- Qwen 7B: RTX 3090 (24GB) 이상
- Qwen 14B: RTX 4090 (24GB) 또는 A100 (40GB)
- Qwen 32B: A100 (80GB) 또는 2x A100 (40GB)
```

#### 1.3 템플릿 선택
- **RunPod PyTorch** 또는 **RunPod Tensorflow** 선택
- Docker가 사전 설치됨
- NVIDIA Container Toolkit 포함

#### 1.4 스토리지 설정
- **Container Disk:** 20GB (모델 캐시용)
- **Volume Disk:** 50GB (영구 데이터용, 선택)

#### 1.5 네트워크 설정
- **Expose HTTP Ports:** `8000, 7860` 추가
  - 8000: vLLM API 서버
  - 7860: Gradio UI

#### 1.6 SSH 키 추가 (선택)
- 본인의 공개 SSH 키 추가

#### 1.7 배포
- **Deploy** 클릭
- Pod 시작 대기 (1~2분)

---

### 2단계: Pod 접속

#### SSH 접속
```bash
# RunPod 대시보드에서 SSH 명령 복사
ssh root@<pod-id>.ssh.runpod.io -p <port> -i ~/.ssh/id_ed25519
```

#### 또는 Web Terminal
- RunPod 대시보드에서 **Terminal** 클릭
- 브라우저에서 바로 접속

---

### 3단계: 프로젝트 업로드

#### 방법 A: Git Clone (권장)
```bash
cd /workspace
git clone https://github.com/your-username/final_project.git
cd final_project
```

#### 방법 B: 파일 업로드
```bash
# 로컬에서 프로젝트 압축
cd C:\develop1
tar -czf final_project.tar.gz final_project/

# RunPod Pod으로 전송
scp -P <port> final_project.tar.gz root@<pod-id>.ssh.runpod.io:/workspace/

# Pod에서 압축 해제
cd /workspace
tar -xzf final_project.tar.gz
cd final_project
```

#### 방법 C: Jupyter Lab 업로드
- RunPod 대시보드에서 **Jupyter Lab** 클릭
- 파일 탐색기에서 드래그 앤 드롭
- `/workspace` 디렉토리에 업로드

---

### 4단계: Docker 및 환경 확인

```bash
# Docker 설치 확인
docker --version

# NVIDIA Docker 런타임 확인
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# 출력 예시:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 525.xx.xx    Driver Version: 525.xx.xx    CUDA Version: 12.0   |
# ...
```

---

### 5단계: 환경 변수 설정

```bash
cd /workspace/final_project

# .env 파일 생성
cp .env.example .env

# 편집
nano .env
```

**RunPod Pod 전용 .env 설정:**
```env
# vLLM 모델
VLLM_MODEL=Qwen/Qwen2.5-Coder-7B-Instruct

# 포트 (기본값 사용)
VLLM_PORT=8000
GRADIO_PORT=7860

# 서버 URL (Pod 내부)
VLLM_SERVER_URL=http://localhost:8000/v1

# Gradio 외부 접속 허용
GRADIO_HOST=0.0.0.0

# HuggingFace 캐시 (Pod 영구 스토리지)
HUGGINGFACE_CACHE_DIR=/workspace/.cache/huggingface

# GPU 메모리 최대 활용
GPU_MEMORY_UTIL=0.95

# (선택) HuggingFace 토큰
HUGGING_FACE_HUB_TOKEN=hf_xxxxxxxxxxxxx

# Keep-Warm 비활성화 (Pod는 항상 실행 중)
ENABLE_KEEP_WARM=false
```

---

### 6단계: vLLM Docker 서버 시작

```bash
# 스크립트로 시작 (권장)
./start_server.sh

# 또는 직접 실행
docker-compose up -d
```

**출력:**
```
🚀 vLLM 서버를 시작합니다...
   첫 실행 시 모델 다운로드로 시간이 걸릴 수 있습니다.

[+] Running 1/1
 ✔ Container vllm-hint-server  Started

✅ vLLM 서버가 백그라운드에서 시작되었습니다!
```

#### 모델 다운로드 모니터링
```bash
# 로그 실시간 확인
docker-compose logs -f vllm-server

# 모델 다운로드 완료 확인
# "INFO: Application startup complete" 출력 대기
```

**첫 실행 시간:**
- Qwen 7B: 약 5~10분 (14GB 다운로드)
- Qwen 14B: 약 10~15분 (28GB 다운로드)

---

### 7단계: 서버 상태 확인

```bash
# 컨테이너 상태
docker-compose ps

# Health check
curl http://localhost:8000/health

# 모델 확인
curl http://localhost:8000/v1/models
```

**정상 출력:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "Qwen/Qwen2.5-Coder-7B-Instruct",
      "object": "model",
      ...
    }
  ]
}
```

---

### 8단계: Gradio 클라이언트 실행

#### 새 터미널 열기 (tmux 권장)
```bash
# tmux 세션 생성
tmux new -s gradio

# 클라이언트 시작
cd /workspace/final_project
./start_client.sh
```

**또는 백그라운드 실행:**
```bash
nohup ./start_client.sh > gradio.log 2>&1 &
```

---

### 9단계: 외부 접속

RunPod은 자동으로 포트를 매핑합니다.

#### 9.1 RunPod 대시보드에서 URL 확인
- Pod 상세 페이지
- **TCP Port Mappings** 섹션
- 포트 7860과 8000의 Public URL 복사

#### 9.2 접속
```
Gradio UI: https://<pod-id>-7860.proxy.runpod.net
vLLM API: https://<pod-id>-8000.proxy.runpod.net
```

---

## 🔧 관리 명령어

### 서버 관리
```bash
# 서버 중지
docker-compose down

# 서버 재시작
docker-compose restart

# 로그 확인
docker-compose logs -f vllm-server

# 컨테이너 내부 접속
docker-compose exec vllm-server bash
```

### 리소스 모니터링
```bash
# GPU 사용률
watch -n 1 nvidia-smi

# 컨테이너 리소스
docker stats vllm-hint-server
```

### 모델 캐시 관리
```bash
# 캐시 위치 확인
ls -lh /workspace/.cache/huggingface/hub

# 캐시 삭제 (재다운로드됨)
rm -rf /workspace/.cache/huggingface/hub
```

---

## 💰 비용 최적화

### 1. Pod 자동 중지
RunPod 대시보드에서:
- **Auto Stop** 설정
- 유휴 시간 후 자동 중지

### 2. Spot Instances
- **Community Cloud** 선택
- 최대 70% 저렴
- 단, 언제든 종료 가능

### 3. 필요할 때만 실행
```bash
# 사용 전 시작
docker-compose up -d

# 사용 후 중지
docker-compose down
```

---

## 🐛 문제 해결

### 1. "NVIDIA runtime not found"
```bash
# nvidia-container-toolkit 설치
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 2. "Out of Memory"
```bash
# .env에서 GPU 메모리 사용률 낮추기
GPU_MEMORY_UTIL=0.8  # 0.95 → 0.8

# 또는 컨텍스트 길이 축소
MAX_MODEL_LEN=2048  # 4096 → 2048

# 서버 재시작
docker-compose restart
```

### 3. "Connection refused"
```bash
# 서버 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs vllm-server

# 포트 확인
netstat -tlnp | grep 8000
```

### 4. 모델 다운로드 느림
```bash
# HuggingFace 토큰 설정
export HUGGING_FACE_HUB_TOKEN="hf_xxxxx"

# 또는 .env 파일 수정
```

---

## 📊 성능 벤치마크

| GPU | 모델 | 추론 속도 | 메모리 | 비용/시간 |
|-----|------|----------|--------|----------|
| RTX 3090 | Qwen 7B | ~80 tok/s | 14GB | $0.24 |
| RTX 4090 | Qwen 7B | ~100 tok/s | 14GB | $0.40 |
| A100 40GB | Qwen 14B | ~90 tok/s | 28GB | $1.10 |
| A100 80GB | Qwen 32B | ~70 tok/s | 50GB | $1.89 |

---

## 🆚 Serverless vs Pod + Docker

| 항목 | Serverless | Pod + Docker |
|------|-----------|-------------|
| **설정** | 간단 | 중간 |
| **관리** | 자동 | 수동 |
| **성능** | 가변 (Cold start) | **고정** ✅ |
| **확장** | 자동 | 수동 |
| **비용** | 사용량 기준 | 시간 기준 |
| **제어** | 제한적 | **완전** ✅ |
| **권장 용도** | 변동 트래픽 | **안정적 서비스** ✅ |

---

## 🎓 추가 리소스

- [vLLM Docker 공식 문서](https://docs.vllm.ai/en/v0.8.0/deployment/docker.html)
- [RunPod 문서](https://docs.runpod.io/)
- [Docker Compose 문서](https://docs.docker.com/compose/)

---

**이 방식은 다음과 같은 경우에 적합합니다:**
- ✅ 24시간 안정적인 서비스 필요
- ✅ 완전한 제어권 필요
- ✅ Docker 환경 커스터마이징 필요
- ✅ 예측 가능한 성능 필요

**Serverless가 더 나은 경우:**
- 간헐적 사용 (비용 절감)
- 트래픽 변동이 큰 경우
- 자동 확장 필요

---

**마지막 업데이트:** 2025-11-05
**테스트 환경:** RunPod Community Cloud, RTX 3090
