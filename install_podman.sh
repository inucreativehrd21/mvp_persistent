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
echo "3️⃣  Podman 설치 중..."

# Ubuntu 버전 확인
. /etc/os-release

# Podman 저장소 추가
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | \
    tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null

apt-get update -qq
apt-get install -y podman

# Podman 버전 확인
PODMAN_VERSION=$(podman --version)
echo "   ✅ $PODMAN_VERSION 설치 완료"

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

# containers.conf 파일 위치 확인 및 생성
CONTAINERS_CONF="/etc/containers/containers.conf"
if [ ! -f "$CONTAINERS_CONF" ]; then
    mkdir -p /etc/containers
    touch "$CONTAINERS_CONF"
fi

# nvidia-ctk로 crun 런타임 설정
nvidia-ctk runtime configure --runtime=crun --config="$CONTAINERS_CONF"

# crun이 기본 런타임인지 확인하고 설정
if ! grep -q "^runtime = \"crun\"" "$CONTAINERS_CONF" 2>/dev/null; then
    echo '[engine]' >> "$CONTAINERS_CONF"
    echo 'runtime = "crun"' >> "$CONTAINERS_CONF"
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

# 먼저 nvidia.com/gpu CDI 방식 테스트
echo "   📋 CDI 방식 테스트 (nvidia.com/gpu=all)..."
if podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
    echo ""
    echo "   ✅ GPU 접근 테스트 성공! (CDI 방식)"
    echo "   ℹ️  nvidia.com/gpu=all 방식을 사용할 수 있습니다."
else
    echo "   ⚠️  CDI 방식 실패, 디바이스 직접 마운트 방식으로 테스트..."
    echo ""
    
    # GPU 디바이스 자동 감지
    GPU_DEVICES=$(ls /dev/nvidia* 2>/dev/null | grep -E "nvidia[0-9]+$" | head -n 1)
    
    if [ -z "$GPU_DEVICES" ]; then
        echo "   ⚠️  GPU 디바이스를 찾을 수 없습니다."
        echo "   수동으로 확인하세요: ls -l /dev/nvidia*"
    else
        GPU_NUM=$(echo $GPU_DEVICES | grep -oE '[0-9]+$')
        echo "   📋 감지된 GPU: /dev/nvidia${GPU_NUM}"
        echo "   📋 직접 마운트 방식 테스트..."
        
        if podman run --rm \
            --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \
            --device /dev/nvidiactl:/dev/nvidiactl \
            --device /dev/nvidia-uvm:/dev/nvidia-uvm \
            docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
            echo ""
            echo "   ✅ GPU 접근 테스트 성공! (디바이스 직접 마운트 방식)"
            echo "   ℹ️  docker-compose.podman.yml에서 /dev/nvidia${GPU_NUM} 사용"
        else
            echo ""
            echo "   ❌ GPU 접근 테스트 실패"
            echo "   수동으로 확인이 필요합니다:"
            echo "   ls -l /dev/nvidia*"
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
echo "설치된 구성요소:"
echo "  - Podman: $(podman --version | cut -d' ' -f3)"
echo "  - podman-compose: $(podman-compose --version | cut -d' ' -f3)"
echo "  - crun: $(crun --version | head -n1)"
echo "  - Python: $(python3 --version | cut -d' ' -f2)"
echo ""
echo "다음 단계:"
echo "  1. 프로젝트 디렉토리로 이동"
echo "  2. .env 파일 설정: cp .env.example .env"
echo "  3. vLLM 서버 시작: ./start_server_podman.sh"
echo "  4. Gradio 클라이언트 시작: ./start_client.sh"
echo ""
echo "상세 가이드: RUNPOD_PODMAN_GUIDE.md"
echo ""
