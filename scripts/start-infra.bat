@echo off
echo ============================================
echo  Sanos y Salvos - Starting Infrastructure
echo ============================================

echo.
echo [1/4] Starting PostgreSQL (with PostGIS)...
echo [2/4] Starting Redis...
echo [3/4] Starting RabbitMQ...
echo [4/4] Starting MinIO + MailHog...
echo.

cd /d "%~dp0.."
docker compose up -d postgres redis rabbitmq minio minio-init mailhog

echo.
echo Waiting for services to be healthy...
timeout /t 20 /nobreak > nul

echo.
echo ============================================
echo  Infrastructure URLs:
echo  - PostgreSQL:     localhost:5432
echo  - Redis:          localhost:6379
echo  - RabbitMQ Mgmt:  http://localhost:15672 (sanos/salvos123)
echo  - MinIO Console:  http://localhost:9001  (minioadmin/minioadmin123)
echo  - MailHog UI:     http://localhost:8025
echo ============================================
echo.
pause
