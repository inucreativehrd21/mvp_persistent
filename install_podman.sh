#!/bin/bash

# =============================================================================
# RunPod Explore Pod - Podman 환경 자동 설치 스크립트
# =============================================================================

set -e

echo "=========================================="
echo "🐳 Podman 환경 자동 설치"
echo "   RunPod Explore Pod 전용"
echo "=========================================="
echo ""

# 관리자 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  이 스크립트는 root 권한이 필요합니다."
    echo "   sudo ./install_podman.sh 로 실행하거나"
    echo "   RunPod에서는 기본적으로 root이므로 그냥 실행하세요."
    exit 1
fi

# 1. 시스템 업데이트
echo "1️⃣  시스템 업데이트 중..."
apt-get update -qq

# 2. 필수 패키지 설치
echo ""
echo "2️⃣  필수 패키지 설치 중..."
apt-get install -y -qq \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release

# 3. Podman 설치
echo ""
echo "3️⃣  Podman 4.x 설치 중..."

# Ubuntu 버전 확인
. /etc/os-release

# 기존 Podman 제거 (있는 경우)
apt-get remove -y podman 2>/dev/null || true

# Podman 4.x를 위한 저장소 추가
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | \
    tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null

# 업데이트 및 Podman 설치
apt-get update -qq
apt-get install -y podman

# Podman 버전 확인
PODMAN_VERSION=$(podman --version)
PODMAN_MAJOR=$(echo "$PODMAN_VERSION" | grep -oP 'version \K[0-9]+')

echo "   ✅ $PODMAN_VERSION 설치 완료"

# 버전 체크
if [ "$PODMAN_MAJOR" -lt 4 ]; then
    echo "   ⚠️  경고: Podman $PODMAN_MAJOR.x가 설치되었습니다."
    echo "   ⚠️  CDI GPU 지원을 위해서는 Podman 4.0+ 권장"
    echo "   ⚠️  직접 디바이스 마운트 방식으로 진행합니다..."
    USE_DIRECT_DEVICE_MOUNT=true
else
    echo "   ℹ️  Podman 4.x 이상: CDI 지원 활성화"
    USE_DIRECT_DEVICE_MOUNT=false
fi

# 4. crun 런타임 설치
echo ""
echo "4️⃣  crun 런타임 설치 중..."
apt-get install -y crun
echo "   ✅ crun 설치 완료"

# 5. NVIDIA Container Toolkit 설치
echo ""
echo "5️⃣  NVIDIA Container Toolkit 설치 중..."

# nvidia-container-toolkit 저장소 추가
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -qq
apt-get install -y nvidia-container-toolkit

echo "   ✅ NVIDIA Container Toolkit 설치 완료"

# 6. NVIDIA CDI 생성
echo ""
echo "6️⃣  NVIDIA CDI (Container Device Interface) 설정 중..."
mkdir -p /etc/cdi
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
echo "   ✅ NVIDIA CDI 설정 완료"

# 7. Podman GPU 설정
echo ""
echo "7️⃣  Podman GPU 접근 설정 중..."

# containers.conf 파일 위치
CONTAINERS_CONF="/etc/containers/containers.conf"
mkdir -p /etc/containers

# 기존 설정 백업 (있는 경우)
if [ -f "$CONTAINERS_CONF" ]; then
    cp "$CONTAINERS_CONF" "${CONTAINERS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Podman 버전에 따른 설정 파일 생성
if [ "$USE_DIRECT_DEVICE_MOUNT" = true ]; then
    # Podman 3.x용 설정 (CDI 없음)
    cat > "$CONTAINERS_CONF" << 'EOF'
[containers]
default_capabilities = [
  "CHOWN",
  "DAC_OVERRIDE",
  "FOWNER",
  "FSETID",
  "KILL",
  "NET_BIND_SERVICE",
  "SETFCAP",
  "SETGID",
  "SETPCAP",
  "SETUID",
  "SYS_CHROOT"
]

[engine]
runtime = "crun"

[engine.runtimes]
crun = [
    "/usr/bin/crun",
    "/usr/sbin/crun",
    "/usr/local/bin/crun",
    "/usr/local/sbin/crun",
    "/sbin/crun",
    "/bin/crun",
    "/run/current-system/sw/bin/crun",
]

runc = [
    "/usr/bin/runc",
    "/usr/sbin/runc",
    "/usr/local/bin/runc",
    "/usr/local/sbin/runc",
    "/sbin/runc",
    "/bin/runc",
    "/usr/lib/cri-o-runc/sbin/runc",
]
EOF
    echo "   ℹ️  Podman 3.x 호환 설정 생성 (CDI 제외)"
else
    # Podman 4.x+ 설정 (CDI 포함)
    cat > "$CONTAINERS_CONF" << 'EOF'
[containers]
default_capabilities = [
  "CHOWN",
  "DAC_OVERRIDE",
  "FOWNER",
  "FSETID",
  "KILL",
  "NET_BIND_SERVICE",
  "SETFCAP",
  "SETGID",
  "SETPCAP",
  "SETUID",
  "SYS_CHROOT"
]

[engine]
runtime = "crun"
cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]

[engine.runtimes]
crun = [
    "/usr/bin/crun",
    "/usr/sbin/crun",
    "/usr/local/bin/crun",
    "/usr/local/sbin/crun",
    "/sbin/crun",
    "/bin/crun",
    "/run/current-system/sw/bin/crun",
]

runc = [
    "/usr/bin/runc",
    "/usr/sbin/runc",
    "/usr/local/bin/runc",
    "/usr/local/sbin/runc",
    "/sbin/runc",
    "/bin/runc",
    "/usr/lib/cri-o-runc/sbin/runc",
]
EOF
    echo "   ℹ️  Podman 4.x+ 설정 생성 (CDI 활성화)"
fi

echo "   ✅ Podman GPU 설정 완료"

# 8. Python 및 pip 확인
echo ""
echo "8️⃣  Python 환경 확인 중..."
if ! command -v python3 &> /dev/null; then
    apt-get install -y python3 python3-pip python3-venv
fi
PYTHON_VERSION=$(python3 --version)
echo "   ✅ $PYTHON_VERSION 설치됨"

# 9. podman-compose 설치
echo ""
echo "9️⃣  podman-compose 설치 중..."
pip3 install --quiet podman-compose
COMPOSE_VERSION=$(podman-compose --version)
echo "   ✅ $COMPOSE_VERSION 설치 완료"

# 10. Podman 시스템 재시작 (설정 적용)
echo ""
echo "🔟 Podman 시스템 재시작 중..."
systemctl restart podman 2>/dev/null || true
echo "   ✅ Podman 재시작 완료"

# 11. GPU 접근 테스트
echo ""
echo "1️⃣1️⃣  GPU 접근 테스트 중..."
echo ""

# GPU 디바이스 확인
echo "   📋 시스템 GPU 디바이스 확인..."
ls -la /dev/nvidia* 2>/dev/null || echo "   ⚠️  /dev/nvidia* 디바이스 없음"
echo ""

# GPU 디바이스 자동 감지
GPU_DEVICES=$(ls /dev/nvidia* 2>/dev/null | grep -E "nvidia[0-9]+$" | head -n 1)

if [ -z "$GPU_DEVICES" ]; then
    echo "   ⚠️  GPU 디바이스를 찾을 수 없습니다."
    echo "   수동으로 확인하세요: ls -l /dev/nvidia*"
    echo ""
else
    GPU_NUM=$(echo $GPU_DEVICES | grep -oE '[0-9]+$')
    echo "   📋 감지된 GPU: /dev/nvidia${GPU_NUM}"
    echo ""
    
    # Podman 4.x+인 경우 CDI 방식 먼저 테스트
    if [ "$USE_DIRECT_DEVICE_MOUNT" = false ]; then
        echo "   📋 CDI 방식 테스트 (nvidia.com/gpu=all)..."
        if podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>&1 | grep -q "Tesla\|GeForce\|Quadro\|NVIDIA"; then
            echo ""
            echo "   ✅ GPU 접근 테스트 성공! (CDI 방식)"
            echo "   ℹ️  nvidia.com/gpu=all 방식을 사용할 수 있습니다."
            echo ""
        else
            echo "   ⚠️  CDI 방식 실패, 직접 마운트 방식으로 시도..."
            USE_DIRECT_DEVICE_MOUNT=true
        fi
    fi
    
    # 직접 마운트 방식 테스트
    if [ "$USE_DIRECT_DEVICE_MOUNT" = true ]; then
        echo "   📋 직접 디바이스 마운트 방식 테스트..."
        echo ""
        echo "   실행 명령:"
        echo "   podman run --rm --security-opt=label=disable \\"
        echo "     --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \\"
        echo "     --device /dev/nvidiactl:/dev/nvidiactl \\"
        echo "     --device /dev/nvidia-uvm:/dev/nvidia-uvm \\"
        echo "     --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \\"
        echo "     docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi"
        echo ""
        echo "   ⏳ CUDA 이미지 다운로드 중... (최초 실행 시 시간이 걸립니다)"
        echo ""
        
        TEST_OUTPUT=$(timeout 180 podman run --rm \
            --security-opt=label=disable \
            --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \
            --device /dev/nvidiactl:/dev/nvidiactl \
            --device /dev/nvidia-uvm:/dev/nvidia-uvm \
            --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
            docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>&1)
        
        TEST_EXIT_CODE=$?
        
        if [ $TEST_EXIT_CODE -eq 124 ]; then
            echo "   ⏱️  테스트 타임아웃 (180초)"
            echo "   ℹ️  이미지 다운로드가 완료되지 않았을 수 있습니다."
            echo "   ℹ️  수동으로 테스트하세요:"
            echo "   podman run --rm --security-opt=label=disable \\"
            echo "     --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \\"
            echo "     --device /dev/nvidiactl:/dev/nvidiactl \\"
            echo "     --device /dev/nvidia-uvm:/dev/nvidia-uvm \\"
            echo "     --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \\"
            echo "     docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi"
            echo ""
        elif echo "$TEST_OUTPUT" | grep -q "Tesla\|GeForce\|Quadro\|NVIDIA"; then
            echo "   ✅ GPU 접근 테스트 성공! (디바이스 직접 마운트 방식)"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TEST_OUTPUT" | head -n 20
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "   ✨ 설정 정보:"
            echo "   ├─ GPU 디바이스: /dev/nvidia${GPU_NUM}"
            echo "   ├─ docker-compose.podman.yml 수정 필요:"
            echo "   │  devices:"
            echo "   │    - /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM}"
            echo "   │    - /dev/nvidiactl:/dev/nvidiactl"
            echo "   │    - /dev/nvidia-uvm:/dev/nvidia-uvm"
            echo "   │    - /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools"
            echo "   │  security_opt:"
            echo "   │    - label=disable"
            echo "   └─ 이 설정은 필수입니다!"
            echo ""
        else
            echo "   ❌ GPU 접근 테스트 실패"
            echo ""
            echo "   디버그 출력:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TEST_OUTPUT"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "   🔍 문제 해결 단계:"
            echo "   1. nvidia-smi 실행 확인:"
            echo "      nvidia-smi"
            echo ""
            echo "   2. GPU 디바이스 권한 확인:"
            echo "      ls -l /dev/nvidia*"
            echo ""
            echo "   3. NVIDIA 드라이버 확인:"
            echo "      cat /proc/driver/nvidia/version"
            echo ""
            echo "   4. 문제 해결 가이드:"
            echo "      cat RUNPOD_GPU_TROUBLESHOOTING.md"
            echo ""
        fi
    fi
fi

# 완료
echo ""
echo "=========================================="
echo "✅ Podman 환경 설치 완료!"
echo "=========================================="
echo ""
echo "📦 설치된 구성요소:"
echo "  ├─ Podman: $(podman --version | cut -d' ' -f3)"
echo "  ├─ podman-compose: $(podman-compose --version 2>/dev/null | grep -oP 'version \K[0-9.]+' || echo '1.5.0')"
echo "  ├─ crun: $(crun --version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo 'installed')"
echo "  └─ Python: $(python3 --version | cut -d' ' -f2)"
echo ""
if [ -n "$GPU_NUM" ]; then
    echo "🎮 GPU 설정:"
    echo "  └─ 감지된 GPU: /dev/nvidia${GPU_NUM}"
    echo ""
fi
echo "📝 다음 단계:"
echo "  1️⃣  docker-compose.podman.yml 수정"
echo "     devices 섹션의 nvidia 번호를 nvidia${GPU_NUM:-X}로 변경"
echo ""
echo "  2️⃣  .env 파일 설정"
echo "     cp .env.example .env"
echo "     nano .env  # HUGGING_FACE_HUB_TOKEN 설정"
echo ""
echo "  3️⃣  vLLM 서버 시작"
echo "     ./start_server_podman.sh"
echo ""
echo "  4️⃣  Gradio 클라이언트 시작 (다른 터미널)"
echo "     ./start_client.sh"
echo ""
echo "📚 문서:"
echo "  ├─ Podman 가이드: RUNPOD_PODMAN_GUIDE.md"
echo "  ├─ GPU 문제 해결: RUNPOD_GPU_TROUBLESHOOTING.md"
echo "  └─ 빠른 시작: QUICKSTART_RUNPOD.md"
echo ""
echo "🔧 유용한 명령어:"
echo "  환경 체크:     ./check_environment.sh"
echo "  문제 해결:     ./troubleshoot.sh"
echo "  수동 GPU 테스트: podman run --rm --security-opt=label=disable \\"
echo "                   --device /dev/nvidia${GPU_NUM:-3}:/dev/nvidia${GPU_NUM:-3} \\"
echo "                   --device /dev/nvidiactl:/dev/nvidiactl \\"
echo "                   --device /dev/nvidia-uvm:/dev/nvidia-uvm \\"
echo "                   docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi"
echo ""
