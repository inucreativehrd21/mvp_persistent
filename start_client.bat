@echo off
REM 클라이언트 애플리케이션 시작 스크립트 (Windows)

echo ==========================================
echo Gradio 클라이언트 애플리케이션 시작
echo ==========================================

REM 가상환경 확인
if not exist "app\venv" (
    echo 📦 가상환경을 생성합니다...
    cd app
    python -m venv venv
    call venv\Scripts\activate.bat
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    cd ..
    echo ✅ 가상환경 생성 완료
) else (
    echo ✅ 기존 가상환경 사용
)

REM 가상환경 활성화
call app\venv\Scripts\activate.bat

REM 데이터 파일 확인
if not exist "data\problems_multi_solution.json" (
    echo.
    echo ❌ 데이터 파일을 찾을 수 없습니다: data\problems_multi_solution.json
    echo    MVP 프로젝트의 problems_multi_solution.json을 data\ 디렉토리에 복사하세요.
    echo.
    pause
    exit /b 1
)

REM 애플리케이션 시작
echo.
echo 🚀 Gradio 애플리케이션을 시작합니다...
echo.

cd app
python app.py %*
