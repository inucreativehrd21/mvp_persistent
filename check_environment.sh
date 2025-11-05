#!/bin/bash

# =============================================================================
# 환경 검증 스크립트
# RunPod Ubuntu 22.04 + Podman 환경 확인
# =============================================================================

echo "=========================================="
echo "🔍 환경 검증"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# =============================================================================
# 1. GPU 확인
# =============================================================================
echo "1️⃣  GPU 확인"
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -n1)
    echo "   ✅ GPU: $GPU_INFO"

    # VRAM 확인
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    if [ "$VRAM" -lt 8000 ]; then
        echo "   ⚠️  GPU 메모리가 8GB 미만입니다."
        echo "      Qwen 7B 모델 실행이 어려울 수 있습니다."
        ((WARNINGS++))
    fi
else
    echo "   ❌ nvidia-smi를 찾을 수 없습니다."
    ((ERRORS++))
fi
echo ""

# =============================================================================
# 2. Podman 확인
# =============================================================================
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

# =============================================================================
# 3. podman-compose 확인
# =============================================================================
echo "3️⃣  podman-compose 확인"
if command -v podman-compose &> /dev/null; then
    COMPOSE_VERSION=$(podman-compose --version 2>/dev/null | head -n1)
    echo "   ✅ $COMPOSE_VERSION"
else
    echo "   ❌ podman-compose가 설치되지 않았습니다."
    echo "      설치: pip3 install podman-compose"
    ((ERRORS++))
fi
echo ""

# =============================================================================
# 4. GPU 디바이스 파일 확인
# =============================================================================
echo "4️⃣  GPU 디바이스 파일 확인"
if [ -e /dev/nvidia0 ] && [ -e /dev/nvidiactl ] && [ -e /dev/nvidia-uvm ]; then
    echo "   ✅ 모든 필수 GPU 디바이스 존재"

    # 사용 가능한 GPU 번호 찾기
    GPU_NUM=""
    for i in {0..9}; do
        if [ -e /dev/nvidia${i} ]; then
            GPU_NUM=$i
            echo "   📋 감지된 GPU: /dev/nvidia${GPU_NUM}"
            break
        fi
    done
else
    echo "   ❌ GPU 디바이스 파일이 없습니다."
    echo "      확인: ls -l /dev/nvidia*"
    ((ERRORS++))
fi
echo ""

# =============================================================================
# 5. Python 환경 확인
# =============================================================================
echo "5️⃣  Python 환경 확인"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ $PYTHON_VERSION"
else
    echo "   ❌ Python3이 설치되지 않았습니다."
    ((ERRORS++))
fi
echo ""

# =============================================================================
# 6. 프로젝트 파일 확인
# =============================================================================
echo "6️⃣  프로젝트 파일 확인"

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

    # GPU 번호 확인
    if [ -n "$GPU_NUM" ]; then
        COMPOSE_GPU=$(grep -oP "/dev/nvidia\K[0-9]+" docker-compose.podman.yml | head -n1)
        if [ "$COMPOSE_GPU" = "$GPU_NUM" ]; then
            echo "   ✅ GPU 번호 일치 (nvidia${GPU_NUM})"
        else
            echo "   ⚠️  GPU 번호 불일치 (compose: nvidia${COMPOSE_GPU}, 시스템: nvidia${GPU_NUM})"
            echo "      ./install_podman.sh 재실행으로 자동 수정 가능"
            ((WARNINGS++))
        fi
    fi
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

# =============================================================================
# 7. 포트 확인
# =============================================================================
echo "7️⃣  포트 사용 확인"
for PORT in 8000 7860; do
    if command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
            echo "   ⚠️  포트 $PORT가 이미 사용 중입니다."
            ((WARNINGS++))
        else
            echo "   ✅ 포트 $PORT 사용 가능"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
            echo "   ⚠️  포트 $PORT가 이미 사용 중입니다."
            ((WARNINGS++))
        else
            echo "   ✅ 포트 $PORT 사용 가능"
        fi
    else
        echo "   ⚠️  netstat/ss가 없어 포트 확인을 건너뜁니다."
        break
    fi
done
echo ""

# =============================================================================
# 8. Podman GPU 접근 테스트
# =============================================================================
echo "8️⃣  Podman GPU 접근 테스트"

if [ -n "$GPU_NUM" ] && command -v podman &> /dev/null; then
    echo "   🧪 GPU 테스트 실행 중..."

    # 이미지가 있는지 확인
    if ! podman images 2>/dev/null | grep -q "nvidia/cuda.*12.1.0-base"; then
        echo "   ⏳ 테스트 이미지 다운로드 중... (최초 1회)"
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
        echo "   ✅ Podman GPU 접근 성공!"
    else
        echo "   ❌ Podman GPU 접근 실패"
        echo "      ./install_podman.sh 재실행 필요"
        ((ERRORS++))
    fi
else
    echo "   ⚠️  Podman 또는 GPU가 없어 테스트를 건너뜁니다."
fi
echo ""

# =============================================================================
# 9. 디스크 공간 확인
# =============================================================================
echo "9️⃣  디스크 공간 확인"
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 20 ]; then
    echo "   ⚠️  사용 가능한 디스크 공간이 20GB 미만입니다: ${AVAILABLE_SPACE}GB"
    echo "      모델 다운로드에 최소 15GB 필요합니다."
    ((WARNINGS++))
else
    echo "   ✅ 사용 가능한 디스크 공간: ${AVAILABLE_SPACE}GB"
fi
echo ""

# =============================================================================
# 결과 요약
# =============================================================================
echo "=========================================="
echo "📊 검증 결과"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ 모든 검사 통과!"
    echo ""
    echo "📝 다음 단계:"
    echo "  1. .env 파일 설정 (필요시): nano .env"
    echo "  2. vLLM 서버 시작: ./start_server_podman.sh"
    echo "  3. Gradio 클라이언트 시작: ./start_client.sh"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  경고 ${WARNINGS}개"
    echo "   일부 기능이 제한될 수 있습니다."
    echo ""
    exit 0
else
    echo "❌ 오류 ${ERRORS}개, 경고 ${WARNINGS}개"
    echo ""
    echo "권장 조치:"
    echo "  1. Podman 환경 설치: ./install_podman.sh"
    echo "  2. 환경 재검증: ./check_environment.sh"
    echo ""
    exit 1
fi
