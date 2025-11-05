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

# 기존 Podman 및 관련 패키지 완전 제거
echo "   🗑️  기존 Podman 제거 중..."
apt-get remove -y podman podman-plugins containernetworking-plugins 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# Podman 4.x 시도 (Ubuntu 22.04+)
if [ "${VERSION_ID}" = "22.04" ] || [ "${VERSION_ID}" = "24.04" ]; then
    echo "   📦 Podman 4.x 저장소 시도 중..."
    
    # Kubic 최신 저장소 추가 시도
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/ /" | \
        tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list > /dev/null
    
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/Release.key" | \
        gpg --dearmor | \
        tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg > /dev/null 2>&1
    
    apt-get update -qq 2>/dev/null
    
    # Podman 4.x 설치 시도
    if apt-cache show podman 2>/dev/null | grep -q "Version: 4\."; then
        echo "   ✅ Podman 4.x 발견!"
        apt-get install -y podman
    else
        echo "   ⚠️  Podman 4.x를 찾을 수 없음, 안정 버전으로 폴백..."
        rm -f /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list
        
        # 안정 저장소로 폴백
        echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | \
            tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
        
        curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
            gpg --dearmor | \
            tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null
        
        apt-get update -qq
        apt-get install -y podman
    fi
else
    # 다른 Ubuntu 버전은 안정 저장소 사용
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | \
        tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | \
        gpg --dearmor | \
        tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null
    
    apt-get update -qq
    apt-get install -y podman
fi

# Podman 버전 확인
PODMAN_VERSION=$(podman --version)
PODMAN_MAJOR=$(echo "$PODMAN_VERSION" | grep -oP 'version \K[0-9]+' || echo "3")

echo "   ✅ $PODMAN_VERSION 설치 완료"

# 버전 체크 및 전략 결정
if [ "$PODMAN_MAJOR" -lt 4 ]; then
    echo ""
    echo "   ⚠️  Podman ${PODMAN_MAJOR}.x 설치됨 (CDI 미지원)"
    echo "   ℹ️  RunPod 환경에서는 Podman 3.x가 표준입니다"
    echo "   ℹ️  직접 디바이스 마운트 방식 사용 (안정적)"
    USE_DIRECT_DEVICE_MOUNT=true
else
    echo ""
    echo "   🎉 Podman ${PODMAN_MAJOR}.x 설치됨 (CDI 지원)"
    echo "   ℹ️  CDI 및 직접 마운트 방식 모두 테스트합니다"
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

echo "   🔧 CDI 파일 생성 중... (WARN 메시지는 무시해도 됩니다)"
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>&1 | grep -E "INFO.*Selecting /dev/nvidia[0-9]|Using driver version|Generated CDI" || true

# CDI 파일이 생성되었는지 확인
if [ -f /etc/cdi/nvidia.yaml ]; then
    GPU_COUNT=$(grep -c "name: nvidia.com/gpu" /etc/cdi/nvidia.yaml || echo "0")
    echo "   ✅ NVIDIA CDI 설정 완료 (GPU ${GPU_COUNT}개 감지)"
else
    echo "   ⚠️  CDI 파일 생성 실패 (직접 마운트 방식 사용)"
fi

# 7. Podman 시스템 설정
echo ""
echo "7️⃣  Podman 시스템 설정 중..."

# rootless 모드 문제 해결
echo "   🔧 rootless 모드 설정 수정 중..."

# /etc/containers/storage.conf 설정
mkdir -p /etc/containers
cat > /etc/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF

echo "   ✅ storage.conf 설정 완료"

# 8. Podman GPU 접근 설정
echo ""
echo "8️⃣  Podman GPU 접근 설정 중..."

# containers.conf 파일 위치
CONTAINERS_CONF="/etc/containers/containers.conf"

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

# 9. Podman을 완전히 root 모드로 강제
echo ""
echo "9️⃣  Podman root 모드 강제 설정 중..."

# Podman 환경 변수 설정으로 rootless 완전 비활성화
cat > /etc/profile.d/podman-root.sh << 'EOF'
# Podman을 항상 root 모드로 실행
export STORAGE_DRIVER=overlay
export STORAGE_OPTS=""
export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
export CONTAINERS_CONF=/etc/containers/containers.conf
EOF

# 현재 세션에도 적용
export STORAGE_DRIVER=overlay
export STORAGE_OPTS=""
export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
export CONTAINERS_CONF=/etc/containers/containers.conf

# user namespace를 사용하지 않도록 설정
cat >> /etc/containers/containers.conf << 'EOF'

[containers]
# Rootless 모드 비활성화
userns = "host"
EOF

echo "   ✅ Root 모드 강제 설정 완료"

# 10. Python 및 pip 확인
echo ""
echo "🔟 Python 환경 확인 중..."
if ! command -v python3 &> /dev/null; then
    apt-get install -y python3 python3-pip python3-venv
fi
PYTHON_VERSION=$(python3 --version)
echo "   ✅ $PYTHON_VERSION 설치됨"

# 11. podman-compose 설치
echo ""
echo "1️⃣1️⃣  podman-compose 설치 중..."
pip3 install --quiet podman-compose
COMPOSE_VERSION=$(podman-compose --version)
echo "   ✅ $COMPOSE_VERSION 설치 완료"

# 12. Podman 시스템 재시작 (설정 적용)
echo ""
echo "1️⃣2️⃣  Podman 시스템 재시작 중..."
systemctl restart podman 2>/dev/null || true
echo "   ✅ Podman 재시작 완료"

# 13. GPU 접근 테스트
echo ""
echo "1️⃣3️⃣  GPU 접근 테스트 중..."
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
        echo ""
        
        # 환경 변수 재확인
        export STORAGE_DRIVER=overlay
        export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
        export CONTAINERS_CONF=/etc/containers/containers.conf
        
        # 이미지 확인
        if ! podman images 2>/dev/null | grep -q "nvidia/cuda.*12.1.0-base"; then
            echo "   ⏳ CUDA 이미지 다운로드 중..."
            podman pull docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 2>&1 | grep -v "is not a shared mount" | grep -v "cannot clone" | grep -E "Pulling|Downloaded|Complete" || true
            echo ""
        fi
        
        echo "   🧪 CDI GPU 테스트 실행 중..."
        CDI_OUTPUT=$(podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>&1 | grep -v "is not a shared mount" | grep -v "cannot clone" || true)
        CDI_EXIT_CODE=$?
        
        if [ $CDI_EXIT_CODE -eq 0 ] && echo "$CDI_OUTPUT" | grep -q "Tesla\|GeForce\|Quadro\|NVIDIA"; then
            echo ""
            echo "   ✅ GPU 접근 테스트 성공! (CDI 방식)"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$CDI_OUTPUT" | head -n 25
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "   ✨ CDI 사용 가능!"
            echo "   ℹ️  docker-compose에서 --device nvidia.com/gpu=all 사용 가능"
            echo ""
        else
            echo ""
            echo "   ⚠️  CDI 방식 실패, 직접 마운트 방식으로 전환..."
            echo "   (이것은 정상입니다. Podman 3.x에서는 CDI가 지원되지 않습니다)"
            echo ""
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
        
        # 환경 변수 재확인
        export STORAGE_DRIVER=overlay
        export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
        export CONTAINERS_CONF=/etc/containers/containers.conf
        
        # 이미지가 이미 있는지 확인
        if podman images 2>/dev/null | grep -q "nvidia/cuda.*12.1.0-base"; then
            echo "   ✓ CUDA 이미지 이미 존재"
        else
            echo "   ⏳ CUDA 이미지 다운로드 중... (최초 실행 시 1-2분 소요)"
            echo "   📦 이미지 크기: ~500MB"
            echo ""
            
            # 이미지 미리 다운로드 (진행상황 표시)
            # WARN 메시지 억제하고 중요 정보만 표시
            podman pull docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 2>&1 | grep -v "is not a shared mount" | grep -v "cannot clone" || true
            
            # 실제 다운로드 성공 여부 확인
            if podman images 2>/dev/null | grep -q "nvidia/cuda.*12.1.0-base"; then
                echo ""
                echo "   ✅ 이미지 다운로드 완료"
            else
                echo ""
                echo "   ⚠️  이미지 다운로드 실패"
                echo "   ℹ️  수동으로 테스트하세요:"
                echo ""
                echo "   podman pull docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04"
                echo ""
                # 이미지 다운로드 실패해도 계속 진행
                return 0
            fi
        fi
        
        echo ""
        echo "   🧪 GPU 접근 테스트 실행 중..."
        echo ""
        
        # 테스트 실행 (WARN 메시지 필터링)
        TEST_OUTPUT=$(podman run --rm \
            --security-opt=label=disable \
            --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \
            --device /dev/nvidiactl:/dev/nvidiactl \
            --device /dev/nvidia-uvm:/dev/nvidia-uvm \
            --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
            docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>&1 | grep -v "is not a shared mount" | grep -v "cannot clone" || true)
        
        TEST_EXIT_CODE=$?
        
        echo ""
        
        # 결과 분석
        if [ $TEST_EXIT_CODE -eq 0 ] && echo "$TEST_OUTPUT" | grep -q "NVIDIA\|Tesla\|GeForce\|Quadro"; then
            echo "   ✅ GPU 접근 테스트 성공! (디바이스 직접 마운트 방식)"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TEST_OUTPUT" | head -n 25
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "   ✨ 설정 정보:"
            echo "   ├─ 🎮 GPU 디바이스: /dev/nvidia${GPU_NUM}"
            echo "   ├─ 📝 docker-compose.podman.yml 수정 필요:"
            echo "   │"
            echo "   │  devices:"
            echo "   │    - /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM}"
            echo "   │    - /dev/nvidiactl:/dev/nvidiactl"
            echo "   │    - /dev/nvidia-uvm:/dev/nvidia-uvm"
            echo "   │    - /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools"
            echo "   │"
            echo "   │  security_opt:"
            echo "   │    - label=disable"
            echo "   │"
            echo "   └─ ⚠️  이 설정은 필수입니다!"
            echo ""
        elif [ $TEST_EXIT_CODE -ne 0 ]; then
            echo "   ❌ GPU 접근 테스트 실패 (종료 코드: $TEST_EXIT_CODE)"
            echo ""
            echo "   디버그 출력:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TEST_OUTPUT"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "   🔍 문제 해결 단계:"
            echo ""
            echo "   1️⃣  호스트에서 nvidia-smi 실행 확인:"
            echo "      nvidia-smi"
            echo ""
            echo "   2️⃣  GPU 디바이스 권한 확인:"
            echo "      ls -l /dev/nvidia*"
            echo ""
            echo "   3️⃣  NVIDIA 드라이버 확인:"
            echo "      cat /proc/driver/nvidia/version"
            echo ""
            echo "   4️⃣  수동으로 다시 테스트:"
            echo "      podman run --rm --security-opt=label=disable \\"
            echo "        --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \\"
            echo "        --device /dev/nvidiactl:/dev/nvidiactl \\"
            echo "        --device /dev/nvidia-uvm:/dev/nvidia-uvm \\"
            echo "        --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \\"
            echo "        docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi"
            echo ""
            echo "   5️⃣  문제 해결 가이드:"
            echo "      cat RUNPOD_GPU_TROUBLESHOOTING.md"
            echo ""
        else
            echo "   ⚠️  예상치 못한 출력"
            echo ""
            echo "   출력 내용:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TEST_OUTPUT"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
