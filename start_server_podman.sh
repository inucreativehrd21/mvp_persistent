#!/bin/bash

# =============================================================================
# vLLM Podman 서버 시작 스크립트
# RunPod Ubuntu 22.04 전용
# =============================================================================

set -e  # 에러 발생 시 즉시 중단

echo "=========================================="
echo "🚀 vLLM 서버 시작 (Podman)"
echo "=========================================="
echo ""

# .env 파일 확인
if [ ! -f .env ]; then
    echo "❌ .env 파일이 없습니다."
    echo ""
    echo "다음 명령으로 .env 파일을 생성하세요:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# .env 파일 로드
export $(grep -v '^#' .env | xargs)

# GPU 확인
echo "1️⃣  GPU 상태 확인 중..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "   ❌ nvidia-smi를 찾을 수 없습니다."
    exit 1
fi

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | sed 's/^/   /'
echo ""

# Podman 확인
echo "2️⃣  Podman 확인 중..."
if ! command -v podman &> /dev/null; then
    echo "   ❌ Podman이 설치되지 않았습니다."
    echo "   설치: ./install_podman.sh"
    exit 1
fi

PODMAN_VERSION=$(podman --version | cut -d' ' -f3)
echo "   ✅ Podman $PODMAN_VERSION"
echo ""

# podman-compose 확인
echo "3️⃣  podman-compose 확인 중..."
if ! command -v podman-compose &> /dev/null; then
    echo "   ❌ podman-compose가 설치되지 않았습니다."
    echo "   설치: pip3 install podman-compose"
    exit 1
fi

echo "   ✅ podman-compose 설치됨"
echo ""

# docker-compose.podman.yml 확인
if [ ! -f docker-compose.podman.yml ]; then
    echo "❌ docker-compose.podman.yml 파일을 찾을 수 없습니다."
    exit 1
fi

# 기존 컨테이너 확인 및 중지
echo "4️⃣  기존 컨테이너 확인 중..."
if podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "vllm-hint-server"; then
    echo "   🔄 기존 컨테이너를 중지합니다..."
    podman-compose -f docker-compose.podman.yml down 2>/dev/null || true
fi
echo "   ✅ 준비 완료"
echo ""

# 컨테이너 시작
echo "5️⃣  vLLM 컨테이너 시작 중..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman-compose -f docker-compose.podman.yml up -d
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 컨테이너 상태 확인
echo "6️⃣  컨테이너 상태 확인 중..."
sleep 2
if podman ps --format "{{.Names}}" | grep -q "vllm-hint-server"; then
    echo "   ✅ 컨테이너가 성공적으로 시작되었습니다!"
else
    echo "   ❌ 컨테이너 시작 실패"
    echo ""
    echo "   로그 확인:"
    echo "   podman logs vllm-hint-server"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ vLLM 서버 시작 완료!"
echo "=========================================="
echo ""
echo "📊 서버 정보:"
echo "  ├─ 모델: ${VLLM_MODEL:-Qwen/Qwen2.5-Coder-7B-Instruct}"
echo "  ├─ 포트: ${VLLM_PORT:-8000}"
echo "  └─ URL: http://localhost:${VLLM_PORT:-8000}"
echo ""
echo "⏳ 첫 실행 시 모델 다운로드에 5~10분 소요됩니다."
echo ""
echo "📝 유용한 명령어:"
echo ""
echo "  로그 확인 (실시간):"
echo "    podman logs -f vllm-hint-server"
echo ""
echo "  컨테이너 상태:"
echo "    podman ps"
echo ""
echo "  Health Check:"
echo "    curl http://localhost:${VLLM_PORT:-8000}/health"
echo ""
echo "  모델 확인:"
echo "    curl http://localhost:${VLLM_PORT:-8000}/v1/models"
echo ""
echo "  서버 중지:"
echo "    podman-compose -f docker-compose.podman.yml down"
echo ""
echo "  서버 재시작:"
echo "    podman-compose -f docker-compose.podman.yml restart"
echo ""
