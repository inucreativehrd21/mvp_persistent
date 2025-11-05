#!/bin/bash

# =============================================================================
# vLLM Podman 서버 시작 스크립트
# RunPod Explore Pod (Docker 데몬 없는 환경) 전용
# =============================================================================

set -e

echo "=========================================="
echo "🚀 vLLM 서버를 시작합니다... (Podman)"
echo "   첫 실행 시 모델 다운로드로 시간이 걸릴 수 있습니다."
echo "=========================================="

# .env 파일 확인
if [ ! -f .env ]; then
    echo "⚠️  .env 파일이 없습니다."
    echo "   .env.example을 복사하여 .env 파일을 생성하세요:"
    echo "   cp .env.example .env"
    exit 1
fi

# GPU 확인
echo ""
echo "GPU 상태 확인 중..."
if ! nvidia-smi &> /dev/null; then
    echo "❌ GPU를 찾을 수 없습니다. NVIDIA 드라이버를 확인하세요."
    exit 1
fi
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""

# Podman 확인
if ! command -v podman &> /dev/null; then
    echo "❌ Podman이 설치되지 않았습니다."
    echo "   설치: apt-get install -y podman"
    exit 1
fi

# podman-compose 확인
if ! command -v podman-compose &> /dev/null; then
    echo "❌ podman-compose가 설치되지 않았습니다."
    echo "   설치: pip install podman-compose"
    exit 1
fi

echo "✅ Podman 환경 확인 완료"
echo ""

# 기존 컨테이너 확인 및 중지
if podman ps -a --format "{{.Names}}" | grep -q "vllm-hint-server"; then
    echo "🔄 기존 vLLM 컨테이너를 중지합니다..."
    podman-compose -f docker-compose.podman.yml down
    echo ""
fi

# 컨테이너 시작
echo "🚀 vLLM Podman 컨테이너를 시작합니다..."
echo ""

# podman-compose로 실행
podman-compose -f docker-compose.podman.yml up -d

echo ""
echo "=========================================="
echo "✅ vLLM 서버가 백그라운드에서 시작되었습니다!"
echo "=========================================="
echo ""
echo "📊 상태 확인:"
echo "   podman-compose -f docker-compose.podman.yml ps"
echo ""
echo "📝 로그 확인:"
echo "   podman-compose -f docker-compose.podman.yml logs -f vllm-server"
echo ""
echo "🔍 Health Check:"
echo "   curl http://localhost:${VLLM_PORT:-8000}/health"
echo ""
echo "🛑 서버 중지:"
echo "   podman-compose -f docker-compose.podman.yml down"
echo ""
echo "모델 다운로드 진행 상황을 확인하려면 로그를 확인하세요."
echo "첫 실행 시 약 5~10분 소요됩니다."
echo ""
