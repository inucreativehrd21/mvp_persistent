# RunPod Explore Pod + Podman 배포 가이드

**배포 방식:** RunPod Explore Pod(Docker 데몬 없는 환경)에서 Podman으로 vLLM 컨테이너 실행

## 🎯 이 방식이란?

```
RunPod Explore Pod (GPU 인스턴스, Docker 데몬 ❌)
└── Podman Container (Docker 대체, 데몬 불필요)
    └── vLLM 서버
        └── Qwen 7B 모델
```

**특징:**
- ✅ Docker 데몬 없이 컨테이너 실행
- ✅ docker-compose.yml 호환
- ✅ 기존 Docker 워크플로우 유지
- ✅ 멘토님이 추천한 Docker 이미지 방식 그대로

**Podman vs Docker:**
- Podman: 데몬 없이 작동 (Daemonless)
- Docker: 데몬 필요 (런팟 Explore Pod에서 불가)
- CLI는 거의 동일: `docker` → `podman`

---

## 📋 사전 준비

### 1. RunPod 계정
- [RunPod](https://www.runpod.io/) 가입
- 결제 수단 등록

### 2. 로컬 환경 (프로젝트 업로드용)
- Git 또는 파일 업로드 준비

---

## 🚀 단계별 배포

### 1단계: RunPod Explore Pod 생성

#### 1.1 RunPod 대시보드 접속
- **Pods** 메뉴 클릭
- **+ Deploy** 클릭

#### 1.2 GPU 선택
```
권장 GPU (모델별):
- Qwen 7B: RTX 3090 (24GB) 이상
- Qwen 14B: RTX 4090 (24GB) 또는 A100 (40GB)
```

#### 1.3 템플릿 선택
- **RunPod PyTorch** 선택
- 이미 Python, CUDA, PyTorch 사전 설치됨

#### 1.4 스토리지 설정
- **Container Disk:** 20GB (모델 캐시용)
- **Volume Disk:** 50GB (영구 데이터용, 선택)

#### 1.5 네트워크 설정
- **Expose HTTP Ports:** `8000, 7860` 추가
  - 8000: vLLM API 서버
  - 7860: Gradio UI

#### 1.6 배포
- **Deploy** 클릭
- Pod 시작 대기 (1~2분)

---

### 2단계: Pod 접속

#### SSH 접속
```bash
# RunPod 대시보드에서 SSH 명령 복사
ssh root@<pod-id>.ssh.runpod.io -p <port>
```

#### 또는 Web Terminal
- RunPod 대시보드에서 **Terminal** 클릭
- 브라우저에서 바로 접속

---

### 3단계: Podman 설치

```bash
# 시스템 업데이트
apt-get update

# Podman 설치
apt-get install -y podman

# 설치 확인
podman --version
# 출력 예시: podman version 3.4.4
```

---

### 4단계: nvidia-container-toolkit 설정

```bash
# NVIDIA Container Toolkit 설치 (GPU 접근용)
apt-get install -y nvidia-container-toolkit

# Podman이 GPU를 사용할 수 있도록 설정
# 방법 1: CDI (Container Device Interface) 생성
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# 방법 2: crun 런타임 설정 (위 방법이 안 되면)
nvidia-ctk runtime configure --runtime=crun --config=/usr/share/containers/containers.conf

# GPU 접근 테스트
podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

**정상 출력:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.xx.xx    Driver Version: 525.xx.xx    CUDA Version: 12.0   |
+-----------------------------------------------------------------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
...
```

**오류 발생 시 대체 방법:**
```bash
# GPU 디바이스를 직접 마운트 (docker-compose.podman.yml에서 이미 설정됨)
podman run --rm \
  --device /dev/nvidia0:/dev/nvidia0 \
  --device /dev/nvidiactl:/dev/nvidiactl \
  --device /dev/nvidia-uvm:/dev/nvidia-uvm \
  docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

---

### 5단계: podman-compose 설치

```bash
# podman-compose 설치 (docker-compose 대체)
pip install podman-compose

# 설치 확인
podman-compose --version
# 출력 예시: podman-compose version 1.0.6
```

---

### 6단계: 프로젝트 업로드

#### 방법 A: Git Clone (권장)
```bash
cd /workspace
git clone https://github.com/your-username/mvp_persistent.git
cd mvp_persistent
```

#### 방법 B: 파일 업로드
```bash
# 로컬에서 프로젝트 압축
cd C:\develop1
tar -czf mvp_persistent.tar.gz mvp_persistent/

# RunPod Pod으로 전송
scp -P <port> mvp_persistent.tar.gz root@<pod-id>.ssh.runpod.io:/workspace/

# Pod에서 압축 해제
cd /workspace
tar -xzf mvp_persistent.tar.gz
cd mvp_persistent
```

---

### 7단계: 환경 변수 설정

```bash
cd /workspace/mvp_persistent

# .env 파일 생성
cp .env.example .env

# 편집
nano .env
```

**RunPod Explore Pod 전용 .env 설정:**
```env
# vLLM 모델
VLLM_MODEL=Qwen/Qwen2.5-Coder-7B-Instruct

# 포트
VLLM_PORT=8000
GRADIO_PORT=7860

# 서버 URL (Pod 내부)
VLLM_SERVER_URL=http://localhost:8000/v1

# Gradio 외부 접속 허용 (중요!)
GRADIO_HOST=0.0.0.0

# HuggingFace 캐시 (Pod 영구 스토리지)
HUGGINGFACE_CACHE_DIR=/workspace/.cache/huggingface

# GPU 메모리 최대 활용
GPU_MEMORY_UTIL=0.95
MAX_MODEL_LEN=4096

# (선택) HuggingFace 토큰
HUGGING_FACE_HUB_TOKEN=hf_xxxxxxxxxxxxx
```

---

### 8단계: vLLM Podman 서버 시작

```bash
# Podman 전용 시작 스크립트 사용
chmod +x start_server_podman.sh
./start_server_podman.sh
```

**출력:**
```
🚀 vLLM 서버를 시작합니다... (Podman)
   첫 실행 시 모델 다운로드로 시간이 걸릴 수 있습니다.

GPU 상태 확인 중...
NVIDIA GeForce RTX 3090, 24576 MiB

✅ Podman 환경 확인 완료

🚀 vLLM Podman 컨테이너를 시작합니다...

[+] Running 1/1
 ✔ Container vllm-hint-server  Started

✅ vLLM 서버가 백그라운드에서 시작되었습니다!
```

#### 모델 다운로드 모니터링
```bash
# 로그 실시간 확인
podman-compose -f docker-compose.podman.yml logs -f vllm-server

# 또는 podman 직접 사용
podman logs -f vllm-hint-server

# "INFO: Application startup complete" 출력 대기
```

**첫 실행 시간:**
- Qwen 7B: 약 5~10분 (14GB 다운로드)
- Qwen 14B: 약 10~15분 (28GB 다운로드)

---

### 9단계: 서버 상태 확인

```bash
# 컨테이너 상태
podman-compose -f docker-compose.podman.yml ps

# 또는
podman ps

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
      "created": 1234567890,
      "owned_by": "vllm"
    }
  ]
}
```

---

### 10단계: Gradio 클라이언트 실행

#### 새 터미널 열기 (tmux 권장)
```bash
# tmux 세션 생성
tmux new -s gradio

# 클라이언트 시작
cd /workspace/mvp_persistent
./start_client.sh
```

**또는 백그라운드 실행:**
```bash
nohup ./start_client.sh > gradio.log 2>&1 &
```

---

### 11단계: 외부 접속

RunPod은 자동으로 포트를 매핑합니다.

#### 11.1 RunPod 대시보드에서 URL 확인
- Pod 상세 페이지
- **TCP Port Mappings** 섹션
- 포트 7860과 8000의 Public URL 복사

#### 11.2 접속
```
Gradio UI: https://<pod-id>-7860.proxy.runpod.net
vLLM API: https://<pod-id>-8000.proxy.runpod.net
```

---

## 🔧 관리 명령어 (Podman)

### 서버 관리
```bash
# 서버 중지
podman-compose -f docker-compose.podman.yml down

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart

# 로그 확인
podman-compose -f docker-compose.podman.yml logs -f vllm-server

# 또는 podman 직접 사용
podman logs -f vllm-hint-server

# 컨테이너 내부 접속
podman exec -it vllm-hint-server bash

# 컨테이너 상태
podman ps -a
```

### 리소스 모니터링
```bash
# GPU 사용률
watch -n 1 nvidia-smi

# 컨테이너 리소스
podman stats vllm-hint-server
```

### 이미지 관리
```bash
# 이미지 목록
podman images

# 이미지 업데이트 (vLLM 새 버전)
podman pull vllm/vllm-openai:latest
podman-compose -f docker-compose.podman.yml down
podman-compose -f docker-compose.podman.yml up -d

# 사용하지 않는 이미지 삭제
podman image prune -a
```

### 모델 캐시 관리
```bash
# 캐시 위치 확인
ls -lh /workspace/.cache/huggingface/hub

# 캐시 크기 확인
du -sh /workspace/.cache/huggingface/hub

# 캐시 삭제 (재다운로드됨)
rm -rf /workspace/.cache/huggingface/hub
```

---

## 🐛 문제 해결

### 1. "GPU 접근 불가" 오류
```bash
# 방법 1: CDI 재생성
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# 방법 2: GPU 디바이스 확인
ls -l /dev/nvidia*

# 방법 3: docker-compose.podman.yml에서 devices 직접 지정 (이미 설정됨)
# devices:
#   - /dev/nvidia0:/dev/nvidia0
#   - /dev/nvidiactl:/dev/nvidiactl
#   - /dev/nvidia-uvm:/dev/nvidia-uvm

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart
```

### 2. "Out of Memory"
```bash
# .env에서 GPU 메모리 사용률 낮추기
GPU_MEMORY_UTIL=0.8  # 0.95 → 0.8

# 또는 컨텍스트 길이 축소
MAX_MODEL_LEN=2048  # 4096 → 2048

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart
```

### 3. "Connection refused"
```bash
# 서버 상태 확인
podman ps

# 로그 확인
podman logs vllm-hint-server

# 포트 확인
netstat -tlnp | grep 8000

# 컨테이너 내부에서 health check
podman exec vllm-hint-server curl http://localhost:8000/health
```

### 4. 모델 다운로드 느림
```bash
# HuggingFace 토큰 설정
export HUGGING_FACE_HUB_TOKEN="hf_xxxxx"

# 또는 .env 파일 수정
nano .env
# HUGGING_FACE_HUB_TOKEN=hf_xxxxx

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart
```

### 5. Podman 설치 실패
```bash
# 저장소 추가
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | \
  tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
  apt-key add -

apt-get update
apt-get install -y podman
```

### 6. "runtime not found" 오류
```bash
# crun 런타임 설치
apt-get install -y crun

# containers.conf 확인
cat /usr/share/containers/containers.conf | grep runtime

# nvidia-container-toolkit 재설정
nvidia-ctk runtime configure --runtime=crun --config=/usr/share/containers/containers.conf

# Podman 재시작
systemctl --user restart podman  # rootless인 경우
# 또는
killall podman  # root인 경우
```

---

## 📊 성능 비교

| 항목 | Docker (데몬) | Podman (데몬리스) |
|------|--------------|------------------|
| **시작 속도** | 빠름 | 약간 느림 |
| **메모리** | 약간 높음 | 낮음 |
| **보안** | 루트 필요 | Rootless 가능 |
| **호환성** | 높음 | 높음 (95%+) |
| **런팟 Explore Pod** | ❌ 불가 | ✅ 가능 |

---

## 🆚 Docker vs Podman 명령어 비교

| Docker | Podman | 설명 |
|--------|--------|------|
| `docker-compose up -d` | `podman-compose -f docker-compose.podman.yml up -d` | 컨테이너 시작 |
| `docker-compose down` | `podman-compose -f docker-compose.podman.yml down` | 컨테이너 중지 |
| `docker ps` | `podman ps` | 컨테이너 목록 |
| `docker logs <container>` | `podman logs <container>` | 로그 확인 |
| `docker exec -it <container> bash` | `podman exec -it <container> bash` | 컨테이너 접속 |

**거의 동일!** `docker` → `podman`만 바꾸면 됩니다.

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
./start_server_podman.sh

# 사용 후 중지
podman-compose -f docker-compose.podman.yml down
```

---

## 🎓 추가 리소스

- [Podman 공식 문서](https://docs.podman.io/)
- [podman-compose GitHub](https://github.com/containers/podman-compose)
- [vLLM Docker 공식 문서](https://docs.vllm.ai/en/latest/deployment/docker.html)
- [RunPod 문서](https://docs.runpod.io/)

---

## ✅ 체크리스트

### 배포 완료 확인
- [ ] RunPod Pod 생성 완료
- [ ] Podman 설치 완료
- [ ] podman-compose 설치 완료
- [ ] nvidia-container-toolkit 설정 완료
- [ ] GPU 접근 테스트 성공
- [ ] 프로젝트 업로드 완료
- [ ] .env 파일 설정 완료
- [ ] vLLM 서버 시작 성공
- [ ] 모델 다운로드 완료
- [ ] Health check 통과
- [ ] Gradio 클라이언트 실행 성공
- [ ] 외부 접속 성공

---

**이 방식의 장점:**
- ✅ 멘토님이 추천한 Docker 이미지 방식 유지
- ✅ 런팟 Explore Pod (데몬 없는 환경)에서 작동
- ✅ docker-compose.yml 호환
- ✅ 기존 워크플로우 변경 최소화

**Docker vs Podman 차이:**
- Docker: 데몬 필요, 런팟 Explore Pod 불가
- Podman: 데몬 불필요, 런팟 Explore Pod 가능

---

**마지막 업데이트:** 2025-11-05
**테스트 환경:** RunPod Explore Pod, RTX 3090, Podman 3.4.4
