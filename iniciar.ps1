# ============================================================
#  Sanos y Salvos - Iniciar todos los servicios
# ============================================================

$SANOS_DIR = $PSScriptRoot
$N8N_DIR   = Join-Path $PSScriptRoot "..\..\n8n"

function Write-Title($msg) {
    Write-Host ""
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "  $('=' * ($msg.Length))" -ForegroundColor DarkCyan
}

function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green  }
function Write-Info($msg) { Write-Host "  [..] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Red    }

Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "         SANOS Y SALVOS - INICIANDO         " -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor Cyan

# ── 1. Sanos y Salvos ────────────────────────────────────────
Write-Title "Levantando plataforma Sanos y Salvos..."
Write-Info "Directorio: $SANOS_DIR"

Push-Location $SANOS_DIR
$result = docker compose up -d 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Servicios Sanos y Salvos iniciados"
} else {
    Write-Err "Error al iniciar Sanos y Salvos:"
    Write-Host $result -ForegroundColor DarkRed
}
Pop-Location

# ── 2. n8n ───────────────────────────────────────────────────
Write-Title "Levantando n8n (Agente Amigo)..."
Write-Info "Directorio: $N8N_DIR"

if (Test-Path $N8N_DIR) {
    Push-Location $N8N_DIR
    $result = docker compose up -d 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "n8n iniciado"
    } else {
        Write-Err "Error al iniciar n8n:"
        Write-Host $result -ForegroundColor DarkRed
    }
    Pop-Location
} else {
    Write-Err "No se encontro el directorio n8n en: $N8N_DIR"
}

# ── 3. Esperar y mostrar estado ───────────────────────────────
Write-Title "Esperando que los servicios esten listos..."
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
    "trato_hecho_n8n"
)

Write-Host ""
Write-Host "  Estado de contenedores:" -ForegroundColor White
Write-Host ""

foreach ($c in $contenedores) {
    $estado = docker inspect --format "{{.State.Status}}" $c 2>$null
    if ($estado -eq "running") {
        Write-Host "  [✓] $c" -ForegroundColor Green
    } elseif ($estado) {
        Write-Host "  [~] $c ($estado)" -ForegroundColor Yellow
    } else {
        Write-Host "  [x] $c (no encontrado)" -ForegroundColor DarkGray
    }
}

# ── 4. URLs de acceso ─────────────────────────────────────────
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "   SISTEMA LISTO - URLs de acceso:" -ForegroundColor White
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
