# ============================================================
#  Sanos y Salvos - Iniciar todos los servicios
# ============================================================

$SANOS_DIR = $PSScriptRoot

Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "       SANOS Y SALVOS - INICIANDO           " -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor Cyan

# ── 1. Levantar todo (plataforma + n8n) ───────────────────────
Write-Host ""
Write-Host "  [1/1] Levantando plataforma + Agente Amigo (n8n)..." -ForegroundColor Yellow

Push-Location $SANOS_DIR
docker compose -f docker-compose.yml -f docker-compose.n8n.yml up -d
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK]  Todos los servicios iniciados" -ForegroundColor Green
} else {
    Write-Host "  [ERR] Error al iniciar los servicios" -ForegroundColor Red
}
Pop-Location

# ── 2. Esperar y mostrar estado ────────────────────────────────
Write-Host ""
Write-Host "  Esperando que los servicios esten listos (5s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$contenedores = @(
    "sanos-frontend",
    "sanos-bff-service",
    "sanos-auth-service",
    "sanos-ms-mascotas",
    "sanos-ms-geolocalizacion",
    "sanos-ms-coincidencias",
    "sanos-postgres",
    "sanos-redis",
    "sanos-rabbitmq",
    "sanos-minio",
    "sanos-mailhog",
    "sanos-n8n"
)

Write-Host ""
Write-Host "  Estado de contenedores:" -ForegroundColor White
Write-Host ""

foreach ($c in $contenedores) {
    $estado = docker inspect --format "{{.State.Status}}" $c 2>$null
    if ($estado -eq "running") {
        Write-Host "  [OK] $c" -ForegroundColor Green
    } elseif ($estado) {
        Write-Host "  [~~] $c ($estado)" -ForegroundColor Yellow
    } else {
        Write-Host "  [--] $c (no encontrado)" -ForegroundColor DarkGray
    }
}

# ── 3. URLs ────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "   SISTEMA LISTO - URLs de acceso:          " -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Plataforma        ->  http://localhost:3000" -ForegroundColor White
Write-Host "  n8n (Agente)      ->  http://localhost:5678" -ForegroundColor White
Write-Host "  API (BFF)         ->  http://localhost:9090" -ForegroundColor White
Write-Host "  MinIO (archivos)  ->  http://localhost:9001" -ForegroundColor White
Write-Host "  Mailhog (emails)  ->  http://localhost:8025" -ForegroundColor White
Write-Host "  RabbitMQ          ->  http://localhost:15672" -ForegroundColor White
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""
