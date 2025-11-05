#!/bin/bash
# 클라이언트 애플리케이션 시작 스크립트 (Linux/Mac)

set -e

echo "=========================================="
echo "Gradio 클라이언트 애플리케이션 시작"
echo "=========================================="

# 가상환경 확인
if [ ! -d "app/venv" ]; then
    echo "📦 가상환경을 생성합니다..."
    cd app
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    cd ..
    echo "✅ 가상환경 생성 완료"
else
    echo "✅ 기존 가상환경 사용"
fi

# 가상환경 활성화
source app/venv/bin/activate

# 데이터 파일 확인
if [ ! -f "data/problems_multi_solution.json" ]; then
    echo ""
    echo "❌ 데이터 파일을 찾을 수 없습니다: data/problems_multi_solution.json"
    echo "   MVP 프로젝트의 problems_multi_solution.json을 data/ 디렉토리에 복사하세요."
    echo ""
    exit 1
fi

# vLLM 서버 연결 확인
echo ""
echo "🔍 vLLM 서버 연결 확인 중..."
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "⚠️  vLLM 서버에 연결할 수 없습니다."
    echo "   ./start_server.sh로 서버를 먼저 시작해주세요."
    echo ""
    read -p "그래도 계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 애플리케이션 시작
echo ""
echo "🚀 Gradio 애플리케이션을 시작합니다..."
echo ""

cd app
python app.py "$@"
