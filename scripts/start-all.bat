@echo off
echo ============================================
echo  Sanos y Salvos - Starting All Services
echo ============================================

cd /d "%~dp0.."
docker compose up -d --build

echo.
echo Waiting for services to start...
timeout /t 30 /nobreak > nul

echo.
echo ============================================
echo  Service URLs:
echo  - Frontend:       http://localhost:3000
echo  - BFF/Gateway:    http://localhost:8080
echo  - Auth Service:   http://localhost:8081/swagger-ui.html
echo  - MS Mascotas:    http://localhost:8082/swagger-ui.html
echo  - MS Geo:         http://localhost:8083/swagger-ui.html
echo  - MS Coincid.:    http://localhost:8084/swagger-ui.html
echo.
echo  Infrastructure:
echo  - PostgreSQL:     localhost:5432
echo  - Redis:          localhost:6379
echo  - RabbitMQ Mgmt:  http://localhost:15672
echo  - MinIO Console:  http://localhost:9001
echo  - MailHog UI:     http://localhost:8025
echo ============================================
echo.
pause
