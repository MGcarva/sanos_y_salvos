@echo off
echo ============================================
echo  Sanos y Salvos - Stopping All
echo ============================================

cd /d "%~dp0.."
docker compose down

echo.
echo All services stopped.
echo To also remove volumes: docker compose down -v
pause
