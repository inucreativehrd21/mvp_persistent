#!/bin/bash

# =============================================================================
# 스크립트 실행 권한 일괄 설정
# =============================================================================

echo "=========================================="
echo "🔑 스크립트 실행 권한 설정"
echo "=========================================="
echo ""

# 모든 .sh 파일에 실행 권한 부여
SCRIPTS=(
    "install_podman.sh"
    "check_environment.sh"
    "start_server_podman.sh"
    "start_server.sh"
    "start_client.sh"
    "troubleshoot.sh"
)

echo "다음 스크립트에 실행 권한을 부여합니다:"
echo ""

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "  ✅ $script"
    else
        echo "  ⚠️  $script (파일 없음, 건너뜀)"
    fi
done

echo ""
echo "=========================================="
echo "✅ 완료!"
echo "=========================================="
echo ""
echo "이제 스크립트를 실행할 수 있습니다:"
echo "  ./install_podman.sh"
echo "  ./check_environment.sh"
echo "  ./start_server_podman.sh"
echo ""
