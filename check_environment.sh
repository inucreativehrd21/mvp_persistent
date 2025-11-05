#!/bin/bash

# =============================================================================
# 환경 검증 스크립트
# Podman + vLLM 실행 환경 체크
# =============================================================================

echo "=========================================="
echo "🔍 환경 검증 시작"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# 1. GPU 확인
echo "1️⃣  GPU 확인"
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
    echo "   ✅ GPU: $GPU_INFO"

    # VRAM 확인
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    if [ "$VRAM" -lt 8000 ]; then
        echo "   ⚠️  GPU 메모리가 8GB 미만입니다. Qwen 7B 모델 실행이 어려울 수 있습니다."
        ((WARNINGS++))
    fi
else
    echo "   ❌ nvidia-smi를 찾을 수 없습니다."
    ((ERRORS++))
fi
echo ""

# 2. Podman 확인
echo "2️⃣  Podman 확인"
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version)
    echo "   ✅ $PODMAN_VERSION"
else
    echo "   ❌ Podman이 설치되지 않았습니다."
    echo "      설치: ./install_podman.sh"
    ((ERRORS++))
fi
echo ""

# 3. podman-compose 확인
echo "3️⃣  podman-compose 확인"
if command -v podman-compose &> /dev/null; then
    COMPOSE_VERSION=$(podman-compose --version)
    echo "   ✅ $COMPOSE_VERSION"
else
    echo "   ❌ podman-compose가 설치되지 않았습니다."
    echo "      설치: pip install podman-compose"
    ((ERRORS++))
fi
echo ""

# 4. crun 확인
echo "4️⃣  crun 런타임 확인"
if command -v crun &> /dev/null; then
    CRUN_VERSION=$(crun --version | head -n1)
    echo "   ✅ $CRUN_VERSION"
else
    echo "   ⚠️  crun이 설치되지 않았습니다."
    echo "      설치: apt-get install -y crun"
    ((WARNINGS++))
fi
echo ""

# 5. NVIDIA Container Toolkit 확인
echo "5️⃣  NVIDIA Container Toolkit 확인"
if command -v nvidia-ctk &> /dev/null; then
    echo "   ✅ nvidia-container-toolkit 설치됨"

    # CDI 파일 확인
    if [ -f /etc/cdi/nvidia.yaml ]; then
        echo "   ✅ NVIDIA CDI 파일 존재"
    else
        echo "   ⚠️  NVIDIA CDI 파일이 없습니다."
        echo "      생성: nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
        ((WARNINGS++))
    fi
else
    echo "   ❌ nvidia-container-toolkit이 설치되지 않았습니다."
    echo "      설치: ./install_podman.sh"
    ((ERRORS++))
fi
echo ""

# 6. GPU 디바이스 파일 확인
echo "6️⃣  GPU 디바이스 파일 확인"
if [ -e /dev/nvidia0 ] && [ -e /dev/nvidiactl ] && [ -e /dev/nvidia-uvm ]; then
    echo "   ✅ 모든 NVIDIA 디바이스 파일 존재"
    ls -l /dev/nvidia* 2>/dev/null | grep -E "nvidia0|nvidiactl|nvidia-uvm" | while read line; do
        echo "      $line"
    done
else
    echo "   ❌ NVIDIA 디바이스 파일이 없습니다."
    echo "      확인: ls -l /dev/nvidia*"
    ((ERRORS++))
fi
echo ""

# 7. Python 환경 확인
echo "7️⃣  Python 환경 확인"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ $PYTHON_VERSION"
else
    echo "   ❌ Python3이 설치되지 않았습니다."
    ((ERRORS++))
fi
echo ""

# 8. 프로젝트 파일 확인
echo "8️⃣  프로젝트 파일 확인"

# .env 파일
if [ -f .env ]; then
    echo "   ✅ .env 파일 존재"
else
    echo "   ⚠️  .env 파일이 없습니다."
    echo "      생성: cp .env.example .env"
    ((WARNINGS++))
fi

# docker-compose.podman.yml
if [ -f docker-compose.podman.yml ]; then
    echo "   ✅ docker-compose.podman.yml 존재"
else
    echo "   ❌ docker-compose.podman.yml이 없습니다."
    ((ERRORS++))
fi

# 데이터 파일
if [ -f data/problems_multi_solution.json ]; then
    echo "   ✅ 데이터 파일 존재"
else
    echo "   ⚠️  data/problems_multi_solution.json이 없습니다."
    ((WARNINGS++))
fi
echo ""

# 9. 포트 확인
echo "9️⃣  포트 사용 확인"
if command -v netstat &> /dev/null || command -v ss &> /dev/null; then
    for PORT in 8000 7860; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
                echo "   ⚠️  포트 $PORT가 이미 사용 중입니다."
                ((WARNINGS++))
            else
                echo "   ✅ 포트 $PORT 사용 가능"
            fi
        else
            if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
                echo "   ⚠️  포트 $PORT가 이미 사용 중입니다."
                ((WARNINGS++))
            else
                echo "   ✅ 포트 $PORT 사용 가능"
            fi
        fi
    done
else
    echo "   ⚠️  netstat/ss가 없어 포트 확인을 건너뜁니다."
    ((WARNINGS++))
fi
echo ""

# 10. Podman GPU 테스트
echo "🔟 Podman GPU 접근 테스트"
echo "   테스트 컨테이너 실행 중..."

# 방법 1: nvidia.com/gpu
if podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
    echo "   ✅ Podman GPU 접근 성공 (nvidia.com/gpu 방식)"
# 방법 2: 디바이스 직접 마운트
elif podman run --rm \
    --device /dev/nvidia0:/dev/nvidia0 \
    --device /dev/nvidiactl:/dev/nvidiactl \
    --device /dev/nvidia-uvm:/dev/nvidia-uvm \
    docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
    echo "   ✅ Podman GPU 접근 성공 (디바이스 직접 마운트 방식)"
    echo "      docker-compose.podman.yml이 이 방식을 사용합니다."
else
    echo "   ❌ Podman에서 GPU에 접근할 수 없습니다."
    echo "      해결: ./install_podman.sh 실행"
    ((ERRORS++))
fi
echo ""

# 11. 디스크 공간 확인
echo "1️⃣1️⃣  디스크 공간 확인"
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 20 ]; then
    echo "   ⚠️  사용 가능한 디스크 공간이 20GB 미만입니다: ${AVAILABLE_SPACE}GB"
    echo "      모델 다운로드에 최소 15GB 필요합니다."
    ((WARNINGS++))
else
    echo "   ✅ 사용 가능한 디스크 공간: ${AVAILABLE_SPACE}GB"
fi
echo ""

# 결과 요약
echo "=========================================="
echo "📊 검증 결과 요약"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ 모든 검사 통과!"
    echo ""
    echo "다음 단계:"
    echo "  1. .env 파일 설정 (필요시)"
    echo "  2. vLLM 서버 시작: ./start_server_podman.sh"
    echo "  3. Gradio 클라이언트 시작: ./start_client.sh"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  경고 $WARNINGS개"
    echo "   일부 기능이 제한될 수 있습니다."
    echo ""
    exit 0
else
    echo "❌ 오류 $ERRORS개, 경고 $WARNINGS개"
    echo "   위의 오류를 해결한 후 다시 시도하세요."
    echo ""
    echo "권장 조치:"
    if [ $ERRORS -gt 0 ]; then
        echo "  1. Podman 환경 설치: ./install_podman.sh"
        echo "  2. 환경 재검증: ./check_environment.sh"
    fi
    echo ""
    exit 1
fi
