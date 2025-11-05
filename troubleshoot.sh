#!/bin/bash

# =============================================================================
# 문제 해결 자동화 스크립트
# Podman + vLLM 환경
# =============================================================================

echo "=========================================="
echo "🔧 문제 해결 도구"
echo "=========================================="
echo ""

# 메뉴 표시
show_menu() {
    echo "문제를 선택하세요:"
    echo ""
    echo "  1) GPU 접근 오류"
    echo "  2) 메모리 부족 (OOM)"
    echo "  3) vLLM 서버 시작 실패"
    echo "  4) Gradio 연결 실패"
    echo "  5) 모델 다운로드 느림/실패"
    echo "  6) 포트 충돌"
    echo "  7) 컨테이너 상태 확인"
    echo "  8) 전체 환경 재설정"
    echo "  9) 로그 수집"
    echo "  0) 종료"
    echo ""
    read -p "선택 (0-9): " choice
}

# 1. GPU 접근 오류
fix_gpu_access() {
    echo ""
    echo "🔧 GPU 접근 문제 해결 중..."
    echo ""

    # GPU 디바이스 확인
    echo "1️⃣  GPU 디바이스 파일 확인"
    ls -l /dev/nvidia* 2>/dev/null || echo "   ❌ GPU 디바이스 파일 없음"
    echo ""

    # nvidia-smi 확인
    echo "2️⃣  nvidia-smi 테스트"
    nvidia-smi || echo "   ❌ nvidia-smi 실패"
    echo ""

    # CDI 재생성
    echo "3️⃣  NVIDIA CDI 재생성"
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
    echo "   ✅ CDI 재생성 완료"
    echo ""

    # Podman GPU 테스트
    echo "4️⃣  Podman GPU 접근 테스트"
    if podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
        echo "   ✅ GPU 접근 성공!"
    else
        echo "   ⚠️  nvidia.com/gpu 방식 실패, 디바이스 직접 마운트 테스트..."
        if podman run --rm \
            --device /dev/nvidia0:/dev/nvidia0 \
            --device /dev/nvidiactl:/dev/nvidiactl \
            --device /dev/nvidia-uvm:/dev/nvidia-uvm \
            docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
            echo "   ✅ GPU 접근 성공! (디바이스 직접 마운트)"
        else
            echo "   ❌ GPU 접근 실패"
            echo ""
            echo "권장 조치: ./install_podman.sh 재실행"
        fi
    fi
}

# 2. 메모리 부족
fix_oom() {
    echo ""
    echo "🔧 메모리 부족 문제 해결 중..."
    echo ""

    if [ ! -f .env ]; then
        echo "❌ .env 파일이 없습니다."
        return
    fi

    echo "현재 설정:"
    grep -E "GPU_MEMORY_UTIL|MAX_MODEL_LEN" .env
    echo ""

    read -p "GPU 메모리 사용률을 0.8로 낮추시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i 's/GPU_MEMORY_UTIL=.*/GPU_MEMORY_UTIL=0.8/' .env
        echo "✅ GPU_MEMORY_UTIL=0.8로 설정"
    fi

    read -p "최대 컨텍스트를 2048로 낮추시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i 's/MAX_MODEL_LEN=.*/MAX_MODEL_LEN=2048/' .env
        echo "✅ MAX_MODEL_LEN=2048로 설정"
    fi

    echo ""
    echo "변경된 설정:"
    grep -E "GPU_MEMORY_UTIL|MAX_MODEL_LEN" .env
    echo ""

    read -p "서버를 재시작하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        podman-compose -f docker-compose.podman.yml restart
        echo "✅ 서버 재시작 완료"
    fi
}

# 3. vLLM 서버 시작 실패
fix_vllm_startup() {
    echo ""
    echo "🔧 vLLM 서버 문제 확인 중..."
    echo ""

    echo "1️⃣  컨테이너 상태"
    podman ps -a --filter name=vllm-hint-server
    echo ""

    echo "2️⃣  최근 로그 (마지막 50줄)"
    podman logs --tail 50 vllm-hint-server 2>/dev/null || echo "   ⚠️  컨테이너가 실행 중이 아닙니다."
    echo ""

    read -p "컨테이너를 재시작하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "컨테이너 중지 중..."
        podman-compose -f docker-compose.podman.yml down

        echo "컨테이너 시작 중..."
        podman-compose -f docker-compose.podman.yml up -d

        echo ""
        echo "로그 실시간 확인:"
        echo "  podman logs -f vllm-hint-server"
    fi
}

# 4. Gradio 연결 실패
fix_gradio_connection() {
    echo ""
    echo "🔧 Gradio 연결 문제 확인 중..."
    echo ""

    echo "1️⃣  vLLM 서버 Health Check"
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "   ✅ vLLM 서버 정상"
        curl -s http://localhost:8000/health
    else
        echo "   ❌ vLLM 서버 응답 없음"
        echo "   vLLM 서버를 먼저 시작하세요: ./start_server_podman.sh"
    fi
    echo ""

    echo "2️⃣  포트 사용 확인"
    if netstat -tlnp 2>/dev/null | grep -q ":8000 "; then
        echo "   ✅ 8000 포트 사용 중"
        netstat -tlnp 2>/dev/null | grep ":8000 "
    else
        echo "   ❌ 8000 포트 사용 안 됨"
    fi
    echo ""

    if netstat -tlnp 2>/dev/null | grep -q ":7860 "; then
        echo "   ✅ 7860 포트 사용 중"
        netstat -tlnp 2>/dev/null | grep ":7860 "
    else
        echo "   ⚠️  7860 포트 사용 안 됨 (Gradio 미실행)"
    fi
    echo ""

    echo "3️⃣  .env 설정 확인"
    if [ -f .env ]; then
        echo "   VLLM_SERVER_URL: $(grep VLLM_SERVER_URL .env | cut -d'=' -f2)"
        echo "   GRADIO_HOST: $(grep GRADIO_HOST .env | cut -d'=' -f2)"
    fi
}

# 5. 모델 다운로드 문제
fix_model_download() {
    echo ""
    echo "🔧 모델 다운로드 문제 확인 중..."
    echo ""

    echo "1️⃣  HuggingFace 캐시 확인"
    CACHE_DIR=$(grep HUGGINGFACE_CACHE_DIR .env 2>/dev/null | cut -d'=' -f2 | sed 's/~/$HOME/')
    CACHE_DIR=${CACHE_DIR:-~/.cache/huggingface}

    if [ -d "$CACHE_DIR" ]; then
        echo "   캐시 위치: $CACHE_DIR"
        echo "   캐시 크기: $(du -sh $CACHE_DIR 2>/dev/null | cut -f1)"
        echo ""
        echo "   다운로드된 모델:"
        ls -lh "$CACHE_DIR/hub" 2>/dev/null | grep "^d" || echo "   (없음)"
    else
        echo "   ⚠️  캐시 디렉토리가 없습니다: $CACHE_DIR"
    fi
    echo ""

    echo "2️⃣  HuggingFace 토큰 확인"
    if grep -q "HUGGING_FACE_HUB_TOKEN=hf_" .env 2>/dev/null; then
        echo "   ✅ HuggingFace 토큰 설정됨"
    else
        echo "   ⚠️  HuggingFace 토큰이 설정되지 않았습니다."
        echo "   Private 모델 사용 시 필요합니다."
        echo "   설정: https://huggingface.co/settings/tokens"
    fi
    echo ""

    echo "3️⃣  디스크 공간 확인"
    df -h . | tail -1
    echo ""

    read -p "캐시를 삭제하고 다시 다운로드하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        read -p "⚠️  정말로 캐시를 삭제하시겠습니까? 모델을 다시 다운로드해야 합니다. (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            rm -rf "$CACHE_DIR/hub"
            echo "✅ 캐시 삭제 완료"
            echo "   서버 재시작 시 모델을 다시 다운로드합니다."
        fi
    fi
}

# 6. 포트 충돌
fix_port_conflict() {
    echo ""
    echo "🔧 포트 사용 확인 중..."
    echo ""

    for PORT in 8000 7860; do
        echo "포트 $PORT:"
        if netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
            echo "   ⚠️  사용 중"
            netstat -tlnp 2>/dev/null | grep ":$PORT "
            echo ""

            read -p "   이 포트를 사용하는 프로세스를 종료하시겠습니까? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                PID=$(netstat -tlnp 2>/dev/null | grep ":$PORT " | awk '{print $7}' | cut -d'/' -f1 | head -n1)
                if [ -n "$PID" ]; then
                    kill $PID
                    echo "   ✅ 프로세스 종료: $PID"
                fi
            fi
        else
            echo "   ✅ 사용 가능"
        fi
        echo ""
    done
}

# 7. 컨테이너 상태 확인
check_container_status() {
    echo ""
    echo "🔍 컨테이너 상태 확인"
    echo ""

    echo "1️⃣  실행 중인 컨테이너"
    podman ps
    echo ""

    echo "2️⃣  모든 컨테이너 (중지된 것 포함)"
    podman ps -a
    echo ""

    echo "3️⃣  이미지"
    podman images
    echo ""

    echo "4️⃣  볼륨"
    podman volume ls
    echo ""

    if podman ps --filter name=vllm-hint-server --format "{{.Names}}" | grep -q vllm-hint-server; then
        echo "5️⃣  vLLM 컨테이너 상세 정보"
        podman inspect vllm-hint-server | grep -A 10 "State"
        echo ""

        echo "6️⃣  리소스 사용"
        podman stats --no-stream vllm-hint-server
    fi
}

# 8. 전체 환경 재설정
reset_environment() {
    echo ""
    echo "⚠️  전체 환경 재설정"
    echo ""
    echo "다음 작업을 수행합니다:"
    echo "  1. 모든 컨테이너 중지 및 삭제"
    echo "  2. vLLM 이미지 삭제"
    echo "  3. Podman 캐시 정리"
    echo ""

    read -p "정말로 재설정하시겠습니까? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "취소됨"
        return
    fi

    echo ""
    echo "1️⃣  컨테이너 중지 및 삭제"
    podman-compose -f docker-compose.podman.yml down
    podman rm -f vllm-hint-server 2>/dev/null || true
    echo "   ✅ 완료"

    echo ""
    echo "2️⃣  vLLM 이미지 삭제"
    podman rmi vllm/vllm-openai:latest 2>/dev/null || echo "   이미 삭제됨"
    echo "   ✅ 완료"

    echo ""
    echo "3️⃣  Podman 시스템 정리"
    podman system prune -f
    echo "   ✅ 완료"

    echo ""
    echo "재설정 완료!"
    echo "다음 명령으로 다시 시작하세요:"
    echo "  ./start_server_podman.sh"
}

# 9. 로그 수집
collect_logs() {
    echo ""
    echo "📝 로그 수집 중..."
    echo ""

    LOG_DIR="troubleshoot_logs_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"

    echo "1️⃣  시스템 정보"
    {
        echo "=== System Info ==="
        uname -a
        echo ""
        echo "=== GPU Info ==="
        nvidia-smi
    } > "$LOG_DIR/system.log" 2>&1

    echo "2️⃣  Podman 정보"
    {
        echo "=== Podman Version ==="
        podman --version
        echo ""
        echo "=== Podman Info ==="
        podman info
    } > "$LOG_DIR/podman.log" 2>&1

    echo "3️⃣  컨테이너 상태"
    {
        echo "=== Running Containers ==="
        podman ps
        echo ""
        echo "=== All Containers ==="
        podman ps -a
    } > "$LOG_DIR/containers.log" 2>&1

    echo "4️⃣  vLLM 로그"
    podman logs vllm-hint-server > "$LOG_DIR/vllm.log" 2>&1 || echo "vLLM 로그 없음" > "$LOG_DIR/vllm.log"

    echo "5️⃣  환경 설정"
    cp .env "$LOG_DIR/env.txt" 2>/dev/null || echo ".env 파일 없음" > "$LOG_DIR/env.txt"

    echo "6️⃣  네트워크 상태"
    {
        echo "=== Ports ==="
        netstat -tlnp 2>/dev/null | grep -E "8000|7860"
        echo ""
        echo "=== Podman Networks ==="
        podman network ls
    } > "$LOG_DIR/network.log" 2>&1

    echo ""
    echo "✅ 로그 수집 완료: $LOG_DIR"
    echo ""
    echo "다음 파일을 확인하세요:"
    ls -lh "$LOG_DIR"
    echo ""
    echo "압축하여 공유:"
    echo "  tar -czf $LOG_DIR.tar.gz $LOG_DIR"
}

# 메인 루프
while true; do
    show_menu

    case $choice in
        1) fix_gpu_access ;;
        2) fix_oom ;;
        3) fix_vllm_startup ;;
        4) fix_gradio_connection ;;
        5) fix_model_download ;;
        6) fix_port_conflict ;;
        7) check_container_status ;;
        8) reset_environment ;;
        9) collect_logs ;;
        0)
            echo ""
            echo "종료합니다."
            exit 0
            ;;
        *)
            echo ""
            echo "❌ 잘못된 선택입니다."
            ;;
    esac

    echo ""
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
done
