#!/bin/bash

# =============================================================================
# Podman Error 125 수정 스크립트
# RunPod Ubuntu 22.04 전용
# =============================================================================

set -e

echo "=========================================="
echo "🔧 Podman 오류 수정"
echo "=========================================="
echo ""

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "❌ 이 스크립트는 root 권한이 필요합니다."
    exit 1
fi

# 1. Podman 프로세스 확인 및 종료
echo "1️⃣  실행 중인 Podman 프로세스 확인..."
if pgrep -x podman > /dev/null; then
    echo "   🔄 Podman 프로세스 종료 중..."
    pkill -9 podman || true
    sleep 2
fi
echo "   ✅ 완료"
echo ""

# 2. Podman 저장소 초기화
echo "2️⃣  Podman 저장소 초기화 중..."

# 기존 저장소 백업 및 제거
if [ -d /var/lib/containers ]; then
    echo "   📦 기존 저장소 백업 중..."
    mv /var/lib/containers /var/lib/containers.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
fi

# 새 저장소 디렉토리 생성
mkdir -p /var/lib/containers/storage
mkdir -p /run/containers/storage

echo "   ✅ 저장소 초기화 완료"
echo ""

# 3. Podman 설정 재생성
echo "3️⃣  Podman 설정 재생성 중..."

# storage.conf
cat > /etc/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
additionalimagestores = []

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
mount_program = "/usr/bin/fuse-overlayfs"
EOF

# containers.conf
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
userns = "host"

[engine]
runtime = "crun"
events_logger = "file"

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

echo "   ✅ 설정 파일 재생성 완료"
echo ""

# 4. 환경 변수 설정
echo "4️⃣  환경 변수 설정 중..."

cat > /etc/profile.d/podman-root.sh << 'EOF'
# Podman을 항상 root 모드로 실행
export STORAGE_DRIVER=overlay
export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
export CONTAINERS_CONF=/etc/containers/containers.conf
EOF

# 현재 세션에 적용
export STORAGE_DRIVER=overlay
export CONTAINERS_STORAGE_CONF=/etc/containers/storage.conf
export CONTAINERS_CONF=/etc/containers/containers.conf

echo "   ✅ 환경 변수 설정 완료"
echo ""

# 5. Podman 시스템 리셋
echo "5️⃣  Podman 시스템 리셋 중..."
podman system reset -f 2>/dev/null || true
echo "   ✅ 시스템 리셋 완료"
echo ""

# 6. Podman 동작 테스트
echo "6️⃣  Podman 동작 테스트..."

# 간단한 테스트
if podman ps -a > /dev/null 2>&1; then
    echo "   ✅ podman ps 성공!"
else
    echo "   ❌ podman ps 실패"
    echo ""
    echo "   디버그 정보:"
    podman ps -a 2>&1 || true
    echo ""
    exit 1
fi

# 이미지 목록 테스트
if podman images > /dev/null 2>&1; then
    echo "   ✅ podman images 성공!"
else
    echo "   ⚠️  podman images 경고 (무시 가능)"
fi

echo ""

# 7. GPU 테스트 (선택)
echo "7️⃣  GPU 접근 테스트 (선택)..."
read -p "   GPU 테스트를 실행하시겠습니까? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # GPU 번호 찾기
    GPU_NUM=""
    for i in {0..9}; do
        if [ -e /dev/nvidia${i} ]; then
            GPU_NUM=$i
            break
        fi
    done

    if [ -n "$GPU_NUM" ]; then
        echo "   🧪 GPU 테스트 실행 중..."

        # CUDA 이미지 다운로드
        if ! podman images | grep -q "nvidia/cuda.*12.1.0-base"; then
            echo "   ⏳ CUDA 이미지 다운로드 중..."
            podman pull docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 > /dev/null 2>&1
        fi

        # GPU 테스트
        TEST_OUTPUT=$(podman run --rm \
            --security-opt=label=disable \
            --device /dev/nvidia${GPU_NUM}:/dev/nvidia${GPU_NUM} \
            --device /dev/nvidiactl:/dev/nvidiactl \
            --device /dev/nvidia-uvm:/dev/nvidia-uvm \
            --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
            docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 \
            nvidia-smi 2>&1 | grep -v "not a shared mount" || true)

        if echo "$TEST_OUTPUT" | grep -q "NVIDIA\|Tesla\|GeForce\|RTX"; then
            echo "   ✅ GPU 접근 성공!"
        else
            echo "   ⚠️  GPU 접근 실패 (나중에 확인)"
        fi
    else
        echo "   ⚠️  GPU를 찾을 수 없습니다."
    fi
fi

echo ""

# 완료
echo "=========================================="
echo "✅ Podman 오류 수정 완료!"
echo "=========================================="
echo ""
echo "📝 다음 단계:"
echo "  1. 터미널을 닫고 다시 열기 (환경 변수 적용)"
echo "  2. 또는 다음 명령 실행:"
echo "     source /etc/profile.d/podman-root.sh"
echo ""
echo "  3. 서버 시작:"
echo "     ./start_server_podman.sh"
echo ""
echo "🔧 추가 명령어:"
echo "  podman ps -a        # 컨테이너 목록"
echo "  podman images       # 이미지 목록"
echo "  podman system info  # 시스템 정보"
echo ""
