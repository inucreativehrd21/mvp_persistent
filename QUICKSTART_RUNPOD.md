# RunPod 빠른 시작 가이드 (Podman)

Docker 데몬 없는 RunPod Explore Pod 환경에서 5분 안에 시작하기

## 🚀 한 줄 요약

```bash
./install_podman.sh && cp .env.example .env && ./start_server_podman.sh
```

---

## 📋 전제 조건

- RunPod Pod 생성 완료 (RTX 3090 이상 권장)
- SSH 또는 Web Terminal 접속
- GPU 8GB+ VRAM

---

## ⚡ 빠른 시작 (5분)

### 1단계: 프로젝트 업로드 (30초)

```bash
cd /workspace
git clone <your-repo-url> mvp_persistent
cd mvp_persistent
```

### 2단계: Podman 환경 설치 (2분)

```bash
chmod +x install_podman.sh
./install_podman.sh
```

**설치되는 것:**
- Podman
- podman-compose
- crun 런타임
- nvidia-container-toolkit
- NVIDIA CDI 설정

### 3단계: 환경 검증 (10초)

```bash
chmod +x check_environment.sh
./check_environment.sh
```

**모든 체크가 ✅면 다음 단계로!**

### 4단계: 환경 변수 설정 (30초)

```bash
cp .env.example .env
nano .env
```

**필수 수정 사항:**
```env
GRADIO_HOST=0.0.0.0  # 외부 접속 허용
HUGGINGFACE_CACHE_DIR=/workspace/.cache/huggingface  # 런팟 영구 스토리지
```

### 5단계: vLLM 서버 시작 (1분 30초)

```bash
chmod +x start_server_podman.sh
./start_server_podman.sh
```

**로그 확인:**
```bash
podman logs -f vllm-hint-server
```

**"Application startup complete" 메시지 대기** (첫 실행 시 모델 다운로드 5~10분)

### 6단계: Gradio 클라이언트 시작 (30초)

새 터미널 열기 (tmux 권장):
```bash
tmux new -s gradio
cd /workspace/mvp_persistent
chmod +x start_client.sh
./start_client.sh
```

### 7단계: 접속

RunPod 대시보드에서:
1. Pod 상세 페이지
2. **TCP Port Mappings** 확인
3. 포트 7860 URL 복사

브라우저에서:
```
https://<pod-id>-7860.proxy.runpod.net
```

---

## ✅ 설치 확인

### 서버 상태
```bash
curl http://localhost:8000/health
```

**예상 출력:**
```json
{"status": "ok"}
```

### 모델 확인
```bash
curl http://localhost:8000/v1/models
```

**예상 출력:**
```json
{
  "object": "list",
  "data": [{"id": "Qwen/Qwen2.5-Coder-7B-Instruct", ...}]
}
```

### 컨테이너 상태
```bash
podman ps
```

**예상 출력:**
```
CONTAINER ID  IMAGE                          STATUS      PORTS                   NAMES
abc123def456  vllm/vllm-openai:latest        Up 2 mins   0.0.0.0:8000->8000/tcp  vllm-hint-server
```

---

## 🔧 자주 사용하는 명령어

### 서버 관리
```bash
# 로그 확인
podman logs -f vllm-hint-server

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart

# 서버 중지
podman-compose -f docker-compose.podman.yml down

# 컨테이너 상태
podman ps -a
```

### GPU 모니터링
```bash
# 실시간 GPU 사용률
watch -n 1 nvidia-smi

# 컨테이너 리소스
podman stats vllm-hint-server
```

### 모델 캐시
```bash
# 캐시 크기 확인
du -sh /workspace/.cache/huggingface/hub

# 캐시 위치
ls -lh /workspace/.cache/huggingface/hub
```

---

## 🐛 문제 발생 시

### GPU 접근 오류
```bash
# 환경 재검증
./check_environment.sh

# Podman 재설치
./install_podman.sh
```

### 메모리 부족
```bash
# .env 파일 수정
nano .env

# GPU_MEMORY_UTIL=0.8 로 낮추기
# MAX_MODEL_LEN=2048 로 낮추기

# 서버 재시작
podman-compose -f docker-compose.podman.yml restart
```

### 포트 충돌
```bash
# 포트 사용 확인
netstat -tlnp | grep 8000
netstat -tlnp | grep 7860

# .env에서 포트 변경
VLLM_PORT=8001
GRADIO_PORT=7861
```

---

## 📊 시간 예상

| 단계 | 시간 | 비고 |
|------|------|------|
| 프로젝트 업로드 | 30초 | Git clone |
| Podman 설치 | 2분 | apt-get, pip |
| 환경 검증 | 10초 | check_environment.sh |
| 환경 변수 설정 | 30초 | .env 수정 |
| 서버 시작 | 1분 30초 | 컨테이너 시작 |
| **첫 실행 모델 다운로드** | **5~10분** | **14GB 다운로드** |
| 클라이언트 시작 | 30초 | Gradio 실행 |
| **총 소요 시간** | **10~15분** | **첫 실행 기준** |

**두 번째 실행부터는 1분 이내!**

---

## 💰 비용 절감 팁

### 1. 필요할 때만 서버 실행
```bash
# 사용 전
./start_server_podman.sh

# 사용 후
podman-compose -f docker-compose.podman.yml down
```

### 2. Spot Instance 사용
- RunPod Community Cloud 선택
- 최대 70% 저렴
- 단, 언제든 종료 가능 (스냅샷 백업 권장)

### 3. GPU 적절히 선택
- Qwen 7B: RTX 3090 ($0.24/시간) ✅ 가성비 최고
- Qwen 7B: RTX 4090 ($0.40/시간) - 성능 우선

---

## 📖 추가 문서

- 상세 가이드: [RUNPOD_PODMAN_GUIDE.md](RUNPOD_PODMAN_GUIDE.md)
- 전체 README: [README.md](README.md)
- Docker 방식: [RUNPOD_POD_DEPLOYMENT.md](RUNPOD_POD_DEPLOYMENT.md) (데몬 필요)

---

## 🆘 도움말

### 환경 검증 실패 시
```bash
./check_environment.sh
# 오류 메시지 확인 후 install_podman.sh 재실행
```

### 모델 다운로드 중단 시
```bash
# 로그 확인
podman logs vllm-hint-server

# 재시작
podman-compose -f docker-compose.podman.yml restart
```

### Gradio 연결 실패 시
```bash
# vLLM 서버 health check
curl http://localhost:8000/health

# 포트 확인
netstat -tlnp | grep 8000
```

---

## ✨ 완료!

이제 브라우저에서 `https://<pod-id>-7860.proxy.runpod.net`로 접속하여 사용하세요!

**즐거운 코딩 되세요! 🎉**
