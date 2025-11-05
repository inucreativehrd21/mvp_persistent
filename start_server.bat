@echo off
REM vLLM Docker 서버 시작 스크립트 (Windows)

echo ==========================================
echo vLLM Docker 서버 시작
echo ==========================================

REM .env 파일 확인
if not exist .env (
    echo ⚠️  .env 파일이 없습니다.
    echo    .env.example을 복사하여 .env를 생성합니다...
    copy .env.example .env
    echo ✅ .env 파일 생성 완료
    echo.
    echo ⚠️  .env 파일을 확인하고 필요시 수정하세요.
    echo.
    pause
)

REM Docker 확인
where docker >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Docker가 설치되어 있지 않습니다.
    echo    https://docs.docker.com/desktop/windows/install/
    pause
    exit /b 1
)

REM Docker Compose 시작
echo.
echo 🚀 vLLM 서버를 시작합니다...
echo    첫 실행 시 모델 다운로드로 시간이 걸릴 수 있습니다.
echo.

docker-compose up -d

echo.
echo ✅ vLLM 서버가 백그라운드에서 시작되었습니다!
echo.
echo 📊 서버 로그: docker-compose logs -f vllm-server
echo 🛑 서버 중지: docker-compose down
echo 🔄 서버 재시작: docker-compose restart
echo.
echo 서버 준비 후 클라이언트를 실행하세요:
echo    start_client.bat
echo.
pause
