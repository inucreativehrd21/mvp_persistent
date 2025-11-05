#!/bin/bash

# =============================================================================
# RunPod Ubuntu 22.04 - Podman 환경 자동 설치 스크립트
# RTX 5090 테스트 완료
# =============================================================================

set -e  # 에러 발생 시 즉시 중단

echo "=========================================="
echo "🐳 Podman 환경 자동 설치"
echo "   RunPod Ubuntu 22.04 전용"
echo "=========================================="
echo ""

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "❌ 이 스크립트는 root 권한이 필요합니다."
    echo "   sudo ./install_podman.sh 로 실행하거나"
    echo "   RunPod에서는 기본적으로 root이므로 그냥 실행하세요."
    exit 1
fi

# =============================================================================
# 1. 시스템 업데이트
# =============================================================================
echo "1️⃣  시스템 업데이트 중..."
apt-get update -qq > /dev/null 2>&1
echo "   ✅ 완료"

# =============================================================================
# 2. 필수 패키지 설치
# =============================================================================
echo ""
echo "2️⃣  필수 패키지 설치 중..."
apt-get install -y -qq \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common > /dev/null 2>&1
echo "   ✅ 완료"

# =============================================================================
# 3. Podman 설치
# =============================================================================
echo ""
echo "3️⃣  Podman 설치 중..."

# Ubuntu 버전 확인
. /etc/os-release
echo "   📋 Ubuntu 버전: $VERSION_ID"

# Podman 저장소 추가
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" > \
    /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg 2>/dev/null

# 업데이트 및 설치
apt-get update -qq > /dev/null 2>&1
apt-get install -y podman > /dev/null 2>&1

# 버전 확인
PODMAN_VERSION=$(podman --version 2>/dev/null | cut -d' ' -f3)
echo "   ✅ Podman $PODMAN_VERSION 설치 완료"

# =============================================================================
# 4. crun 런타임 설치
# =============================================================================
echo ""
echo "4️⃣  crun 런타임 설치 중..."
apt-get install -y crun > /dev/null 2>&1
CRUN_VERSION=$(crun --version 2>/dev/null | head -n1 | awk '{print $3}')
echo "   ✅ crun $CRUN_VERSION 설치 완료"

# =============================================================================
# 5. NVIDIA Container Toolkit 설치
# =============================================================================
echo ""
echo "5️⃣  NVIDIA Container Toolkit 설치 중..."

# 저장소 추가
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' > \
    /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -qq > /dev/null 2>&1
apt-get install -y nvidia-container-toolkit > /dev/null 2>&1

echo "   ✅ NVIDIA Container Toolkit 설치 완료"

# =============================================================================
# 6. Podman 설정 파일 생성
# =============================================================================
echo ""
echo "6️⃣  Podman 설정 중..."

# containers.conf 생성
mkdir -p /etc/containers
cat > /etc/containers/containers.conf << 'EOF'
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
EOF

# storage.conf 생성
cat > /etc/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF

echo "   ✅ 설정 파일 생성 완료"

# =============================================================================
# 7. Python 및 podman-compose 설치
# =============================================================================
echo ""
echo "7️⃣  Python 및 podman-compose 설치 중..."

# Python 확인/설치
if ! command -v python3 &> /dev/null; then
    apt-get install -y python3 python3-pip python3-venv > /dev/null 2>&1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "   ✅ Python $PYTHON_VERSION"

# podman-compose 설치
pip3 install --quiet podman-compose 2>/dev/null

if command -v podman-compose &> /dev/null; then
    COMPOSE_VERSION=$(podman-compose --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n1)
    echo "   ✅ podman-compose ${COMPOSE_VERSION:-설치완료}"
else
    echo "   ⚠️  podman-compose PATH 설정 필요"
fi

# =============================================================================
# 8. GPU 디바이스 확인 및 테스트
# =============================================================================
echo ""
echo "8️⃣  GPU 확인 및 테스트"
echo ""

# GPU 디바이스 확인
echo "   📋 GPU 디바이스 검색 중..."
if ! ls /dev/nvidia* > /dev/null 2>&1; then
    echo "   ❌ GPU 디바이스를 찾을 수 없습니다."
    echo "   nvidia-smi로 GPU 상태를 확인하세요."
    exit 1
fi

# 사용 가능한 GPU 찾기
GPU_NUM=""
for i in {0..9}; do
    if [ -e /dev/nvidia${i} ]; then
        GPU_NUM=$i
        break
    fi
done

if [ -z "$GPU_NUM" ]; then
    echo "   ❌ 사용 가능한 GPU를 찾을 수 없습니다."
    exit 1
fi

echo "   ✅ GPU 감지: /dev/nvidia${GPU_NUM}"
echo ""

# nvidia-smi로 GPU 정보 확인
if command -v nvidia-smi &> /dev/null; then
    echo "   📊 GPU 정보:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -n1 | sed 's/^/      /'
    echo ""
fi

# =============================================================================
# 9. Podman GPU 접근 테스트
# =============================================================================
echo "9️⃣  Podman GPU 접근 테스트"
echo ""

# CUDA 이미지 다운로드
echo "   ⏳ CUDA 테스트 이미지 다운로드 중... (최초 1회, 1-2분 소요)"
podman pull docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 > /dev/null 2>&1

# GPU 테스트 실행
echo "   🧪 GPU 접근 테스트 실행 중..."
echo ""

TEST_OUTPUT=$(podman run --rm \
    --security-opt=label=disable \
    --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \
    --device /dev/nvidiactl:/dev/nvidiactl \
    --device /dev/nvidia-uvm:/dev/nvidia-uvm \
    --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
    docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 \
    nvidia-smi 2>&1 | grep -v "not a shared mount" || true)

if echo "$TEST_OUTPUT" | grep -q "NVIDIA\|Tesla\|GeForce\|RTX"; then
    echo "   ✅ GPU 접근 테스트 성공!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$TEST_OUTPUT" | head -n 20
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    echo "   ❌ GPU 접근 테스트 실패"
    echo ""
    echo "   디버그 출력:"
    echo "$TEST_OUTPUT"
    echo ""
    echo "   문제 해결:"
    echo "   1. nvidia-smi 실행 확인"
    echo "   2. ls -l /dev/nvidia* 확인"
    exit 1
fi

# =============================================================================
# 10. docker-compose.podman.yml 자동 업데이트
# =============================================================================
echo "🔟 docker-compose.podman.yml 자동 업데이트"
echo ""

if [ -f docker-compose.podman.yml ]; then
    # 백업 생성
    cp docker-compose.podman.yml docker-compose.podman.yml.backup.$(date +%Y%m%d_%H%M%S)

    # GPU 번호 업데이트
    sed -i "s|/dev/nvidia[0-9]:/dev/nvidia[0-9]|/dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM}|g" docker-compose.podman.yml

    echo "   ✅ GPU 번호를 nvidia${GPU_NUM}로 업데이트했습니다."
    echo "   📋 백업 파일이 생성되었습니다."
else
    echo "   ⚠️  docker-compose.podman.yml 파일을 찾을 수 없습니다."
    echo "   프로젝트 루트 디렉토리에서 실행하세요."
fi

# =============================================================================
# 완료
# =============================================================================
echo ""
echo "=========================================="
echo "✅ Podman 환경 설치 완료!"
echo "=========================================="
echo ""
echo "📦 설치된 구성요소:"
echo "  ├─ Podman: $PODMAN_VERSION"
echo "  ├─ crun: $CRUN_VERSION"
echo "  ├─ Python: $PYTHON_VERSION"
echo "  └─ podman-compose: 설치완료"
echo ""
echo "🎮 GPU 설정:"
echo "  └─ 감지된 GPU: /dev/nvidia${GPU_NUM}"
echo ""
echo "📝 다음 단계:"
echo ""
echo "  1️⃣  .env 파일 설정"
echo "     cp .env.example .env"
echo "     nano .env"
echo ""
echo "  2️⃣  환경 검증 (선택)"
echo "     ./check_environment.sh"
echo ""
echo "  3️⃣  vLLM 서버 시작"
echo "     ./start_server_podman.sh"
echo ""
echo "  4️⃣  Gradio 클라이언트 시작 (새 터미널)"
echo "     ./start_client.sh"
echo ""
echo "🔧 유용한 명령어:"
echo "  podman ps              # 실행 중인 컨테이너"
echo "  podman logs -f <name>  # 로그 확인"
echo "  podman images          # 이미지 목록"
echo ""
echo "📚 문서:"
echo "  QUICKSTART_RUNPOD.md        # 빠른 시작"
echo "  RUNPOD_PODMAN_GUIDE.md      # 상세 가이드"
echo ""
