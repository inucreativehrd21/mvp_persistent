# RunPod GPU 접근 문제 해결 가이드

## 🔍 문제 분석 결과

### RunPod 환경에서 발견된 문제들

#### 1. **Podman 버전 문제 (3.4.4)**
```
WARN[0000] Failed to decode the keys ["engine.cdi_spec_dirs"]
```

**원인:**
- RunPod Ubuntu 22.04에 기본 설치되는 Podman은 **3.4.4 버전**
- Podman 3.x는 **CDI (Container Device Interface)를 지원하지 않음**
- CDI는 Podman 4.0+부터 공식 지원

**영향:**
- `nvidia.com/gpu=all` 방식 사용 불가
- `cdi_spec_dirs` 설정이 무시됨
- NVIDIA CDI 설정 파일(`/etc/cdi/nvidia.yaml`)이 작동하지 않음

#### 2. **GPU 디바이스 번호 (nvidia3)**
```
INFO[0000] Selecting /dev/nvidia3 as /dev/nvidia3
```

**원인:**
- RunPod은 멀티-GPU 서버의 특정 GPU를 할당
- 사용자에게는 `/dev/nvidia3`처럼 특정 번호의 GPU가 할당됨
- `docker-compose.podman.yml`에 하드코딩된 `/dev/nvidia0`와 불일치

**영향:**
- GPU 접근 실패
- 컨테이너가 GPU를 찾지 못함

#### 3. **SELinux 레이블 문제**
**원인:**
- Podman은 기본적으로 SELinux를 사용
- GPU 디바이스 접근 시 레이블 충돌 가능

**해결:**
- `--security-opt=label=disable` 필수

---

## ✅ 해결 방법

### 방법 1: 자동 설치 스크립트 사용 (권장)

업데이트된 `install_podman.sh` 스크립트를 실행하세요:

```bash
# 1. 스크립트 실행
chmod +x install_podman.sh
./install_podman.sh

# 2. 스크립트가 자동으로:
#    - Podman 버전 확인
#    - 적절한 설정 파일 생성
#    - GPU 번호 자동 감지
#    - 테스트 수행
```

### 방법 2: 수동 설정

#### Step 1: GPU 번호 확인
```bash
ls -l /dev/nvidia*
# 출력 예시:
# /dev/nvidia3
# /dev/nvidiactl
# /dev/nvidia-uvm
# /dev/nvidia-uvm-tools
```

#### Step 2: `docker-compose.podman.yml` 수정
```yaml
devices:
  - /dev/nvidia3:/dev/nvidia3  # ← 여기를 실제 GPU 번호로 변경
  - /dev/nvidiactl:/dev/nvidiactl
  - /dev/nvidia-uvm:/dev/nvidia-uvm
  - /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools
security_opt:
  - label=disable  # ← 필수!
```

#### Step 3: GPU 테스트
```bash
# 직접 podman으로 테스트
podman run --rm \
  --security-opt=label=disable \
  --device /dev/nvidia3:/dev/nvidia3 \
  --device /dev/nvidiactl:/dev/nvidiactl \
  --device /dev/nvidia-uvm:/dev/nvidia-uvm \
  --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
  docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# 성공 시 GPU 정보가 출력됨
```

---

## 🐛 디버깅 명령어

### 1. 시스템 GPU 확인
```bash
# NVIDIA 드라이버 버전
cat /proc/driver/nvidia/version

# GPU 목록
nvidia-smi

# GPU 디바이스 파일
ls -la /dev/nvidia*
```

### 2. Podman 설정 확인
```bash
# Podman 버전
podman --version

# containers.conf 내용
cat /etc/containers/containers.conf

# CDI 파일 (Podman 4.x+에서만 의미)
cat /etc/cdi/nvidia.yaml 2>/dev/null || echo "CDI 파일 없음"
```

### 3. 런타임 확인
```bash
# crun 위치
which crun

# crun 버전
crun --version

# Podman이 인식하는 런타임
podman info | grep -A 5 runtime
```

---

## 📊 Podman 버전별 지원 여부

| 기능 | Podman 3.x | Podman 4.x+ |
|------|-----------|-------------|
| CDI (`nvidia.com/gpu=all`) | ❌ 미지원 | ✅ 지원 |
| 직접 디바이스 마운트 | ✅ 지원 | ✅ 지원 |
| `cdi_spec_dirs` 설정 | ❌ 미지원 | ✅ 지원 |
| `--security-opt=label=disable` | ✅ 필요 | ✅ 필요 |

---

## 🎯 RunPod 최적 설정

### Podman 3.x 환경 (RunPod 기본)

```yaml
# docker-compose.podman.yml
services:
  vllm-server:
    devices:
      - /dev/nvidia3:/dev/nvidia3  # RunPod GPU 번호
      - /dev/nvidiactl:/dev/nvidiactl
      - /dev/nvidia-uvm:/dev/nvidia-uvm
      - /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools
    security_opt:
      - label=disable  # 필수!
```

```toml
# /etc/containers/containers.conf
[engine]
runtime = "crun"

[engine.runtimes]
crun = ["/usr/bin/crun"]
```

---

## 🚀 빠른 시작

```bash
# 1. 저장소 클론
git clone https://github.com/inucreativehrd21/mvp_persistent.git
cd mvp_persistent

# 2. Podman 설치
chmod +x install_podman.sh
./install_podman.sh

# 3. GPU 번호 확인
ls -l /dev/nvidia*

# 4. docker-compose.podman.yml 수정
# devices 섹션의 nvidia 번호를 실제 GPU 번호로 변경

# 5. 환경 변수 설정
cp .env.example .env
nano .env  # HUGGING_FACE_HUB_TOKEN 설정

# 6. 서버 시작
./start_server_podman.sh
```

---

## 💡 자주 묻는 질문

### Q: CDI를 꼭 사용해야 하나요?
**A:** 아니요. Podman 3.x에서는 직접 디바이스 마운트 방식이 더 안정적입니다.

### Q: nvidia0 대신 nvidia3을 사용하는 이유는?
**A:** RunPod은 멀티-GPU 서버의 특정 GPU를 할당합니다. 각 사용자는 다른 번호를 받을 수 있습니다.

### Q: --security-opt=label=disable을 빼면 안되나요?
**A:** 안됩니다. GPU 디바이스 접근 시 SELinux 레이블 충돌이 발생할 수 있습니다.

### Q: Podman 4.x로 업그레이드하려면?
**A:** 업데이트된 `install_podman.sh`가 자동으로 시도합니다. 하지만 RunPod 환경에서는 3.x가 안정적입니다.

---

## 📝 요약

### 핵심 포인트
1. ✅ **Podman 3.x 환경 수용** - CDI 대신 직접 디바이스 마운트
2. ✅ **GPU 번호 확인** - `/dev/nvidia3` 등 실제 번호 사용
3. ✅ **SELinux 레이블 비활성화** - `--security-opt=label=disable`
4. ✅ **모든 GPU 디바이스 마운트** - nvidia3, nvidiactl, nvidia-uvm, nvidia-uvm-tools

### 성공 체크리스트
- [ ] `nvidia-smi` 실행 성공
- [ ] `/dev/nvidia*` 디바이스 존재 확인
- [ ] `docker-compose.podman.yml`에 올바른 GPU 번호 설정
- [ ] `security_opt: label=disable` 설정
- [ ] podman 테스트 명령 성공
- [ ] vLLM 컨테이너가 GPU 인식

---

**문제가 계속되면:**
1. `./troubleshoot.sh` 실행
2. `./check_environment.sh` 실행
3. 출력 결과를 이슈에 첨부
