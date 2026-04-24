# ================================================================
# REGISTER BACKEND — Sanos y Salvos
# ================================================================
# Ejecutar DESPUES de lanzar manualmente el EC2 desde la consola.
# Registra la IP privada del EC2 en el target group del ALB.
#
# Uso:
#   .\register-backend.ps1 -InstanceId i-XXXXXXXXXXXX
# ================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$SCRIPT_DIR = $PSScriptRoot

# ================================================================
# 1. LEER CREDENCIALES
# ================================================================
Write-Host ""
Write-Host "==> [1/4] Leyendo credenciales..." -ForegroundColor Cyan

$credContent  = Get-Content (Join-Path $SCRIPT_DIR "credentials.tf") -Raw
$accessKey    = [regex]::Match($credContent, 'aws_access_key\s*=\s*"([^"]+)"').Groups[1].Value
$secretKey    = [regex]::Match($credContent, 'aws_secret_key\s*=\s*"([^"]+)"').Groups[1].Value
$sessionToken = [regex]::Match($credContent, 'aws_session_token\s*=\s*"([^"]+)"').Groups[1].Value

if (-not $accessKey) { Write-Host "ERROR: No se leyeron credenciales" -ForegroundColor Red; exit 1 }

$env:AWS_ACCESS_KEY_ID     = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_SESSION_TOKEN     = $sessionToken
$env:AWS_DEFAULT_REGION    = "us-east-1"

Write-Host "    OK" -ForegroundColor Green

# ================================================================
# 2. LEER CONFIG GUARDADA
# ================================================================
Write-Host ""
Write-Host "==> [2/4] Leyendo configuracion guardada..." -ForegroundColor Cyan

$configFile = Join-Path $SCRIPT_DIR "backend-config.json"
if (-not (Test-Path $configFile)) {
    Write-Host "ERROR: No se encontro $configFile" -ForegroundColor Red
    Write-Host "       Ejecuta primero .\deploy-backend.ps1" -ForegroundColor Red
    exit 1
}
$cfg = Get-Content $configFile | ConvertFrom-Json
Write-Host "    TG BFF ARN: $($cfg.TG_BFF_ARN)" -ForegroundColor Green

# ================================================================
# 3. OBTENER IP PRIVADA DEL EC2
# ================================================================
Write-Host ""
Write-Host "==> [3/4] Obteniendo IPs del EC2 $InstanceId..." -ForegroundColor Cyan

# Esperar a que la instancia quede "running"
$intentos = 0
do {
    $state = (aws ec2 describe-instances `
        --instance-ids $InstanceId `
        --query "Reservations[0].Instances[0].State.Name" `
        --output text 2>&1).Trim()
    if ($state -ne "running") {
        $intentos++
        Write-Host "    Estado: $state (intento $intentos/20, esperando...)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
} while ($state -ne "running" -and $intentos -lt 20)

if ($state -ne "running") {
    Write-Host "ERROR: La instancia $InstanceId no esta en estado running (estado: $state)" -ForegroundColor Red
    exit 1
}

$privateIp = (aws ec2 describe-instances `
    --instance-ids $InstanceId `
    --query "Reservations[0].Instances[0].PrivateIpAddress" `
    --output text 2>&1).Trim()

$publicIp = (aws ec2 describe-instances `
    --instance-ids $InstanceId `
    --query "Reservations[0].Instances[0].PublicIpAddress" `
    --output text 2>&1).Trim()

Write-Host "    IP privada: $privateIp" -ForegroundColor Green
Write-Host "    IP publica: $publicIp" -ForegroundColor Green

# ================================================================
# 4. REGISTRAR EN TARGET GROUP DEL ALB
# ================================================================
Write-Host ""
Write-Host "==> [4/4] Registrando en target group del ALB (puerto 8080)..." -ForegroundColor Cyan

aws elbv2 register-targets `
    --target-group-arn $cfg.TG_BFF_ARN `
    --targets "Id=$privateIp,Port=8080" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "    Registrado OK" -ForegroundColor Green
} else {
    Write-Host "    ERROR al registrar en target group" -ForegroundColor Red
    exit 1
}

# ================================================================
# RESUMEN
# ================================================================
$keyFile = Join-Path $SCRIPT_DIR "$($cfg.PROYECTO)-backend-key.pem"
$albDns  = $cfg.ALB_DNS

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  BACKEND REGISTRADO EN ALB" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Instance ID : $InstanceId" -ForegroundColor White
Write-Host "  IP Privada  : $privateIp  (usado por ALB)" -ForegroundColor White
Write-Host "  IP Publica  : $publicIp" -ForegroundColor White
Write-Host ""
Write-Host "  API (via ALB) : http://$albDns/api/" -ForegroundColor Green
Write-Host "  Frontend      : http://sanos-y-salvos-frontend-$($cfg.ACCOUNT_ID).s3-website-$($cfg.REGION).amazonaws.com" -ForegroundColor Green
Write-Host ""
Write-Host "  Los servicios demoran ~3-5 min en inicializar (Spring Boot + Hibernate)." -ForegroundColor Yellow
Write-Host "  El ALB demora hasta 90s adicionales en marcar el target como healthy." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Verificar health del target group:" -ForegroundColor Cyan
Write-Host "    aws elbv2 describe-target-health --target-group-arn $($cfg.TG_BFF_ARN)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Ver logs en el EC2 (via SSH):" -ForegroundColor Cyan
Write-Host "    ssh -i $keyFile -o StrictHostKeyChecking=no ec2-user@$publicIp" -ForegroundColor Gray
Write-Host "    sudo tail -f /var/log/sanos-deploy.log" -ForegroundColor Gray
Write-Host "    sudo docker ps" -ForegroundColor Gray
Write-Host "    sudo docker logs -f bff-service" -ForegroundColor Gray
Write-Host ""
