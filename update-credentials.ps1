# =============================================================
# update-credentials.ps1 — Renovar credenciales AWS Academy
# =============================================================
# Ejecutar al inicio de cada sesión de AWS Academy Learner Lab.
# Actualiza credentials.tf automáticamente con las nuevas claves.
#
# USO:
#   .\update-credentials.ps1
#   (pegar las 3 líneas del panel "AWS Details" cuando se solicite)
#
# O pasar directamente:
#   .\update-credentials.ps1 -AccessKey "ASIA..." -SecretKey "..." -SessionToken "..."
# =============================================================

param(
    [string]$AccessKey    = "",
    [string]$SecretKey    = "",
    [string]$SessionToken = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sanos y Salvos - Actualizar Credenciales " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------
# Si no se pasan parámetros, pedir pegado interactivo
# ---------------------------------------------------------
if (-not $AccessKey -or -not $SecretKey -or -not $SessionToken) {
    Write-Host "Pega las 3 lineas del panel 'AWS Details' de AWS Academy." -ForegroundColor Yellow
    Write-Host "Formato esperado (una por linea):" -ForegroundColor Gray
    Write-Host "  aws_access_key_id=ASIA..."
    Write-Host "  aws_secret_access_key=..."
    Write-Host "  aws_session_token=..."
    Write-Host ""
    Write-Host "Pega y presiona ENTER dos veces cuando termines:" -ForegroundColor Yellow

    $lines = @()
    while ($true) {
        $line = Read-Host
        if ($line -eq "") { break }
        $lines += $line
    }

    foreach ($line in $lines) {
        if ($line -match "aws_access_key_id\s*=\s*(.+)") {
            $AccessKey = $Matches[1].Trim()
        }
        elseif ($line -match "aws_secret_access_key\s*=\s*(.+)") {
            $SecretKey = $Matches[1].Trim()
        }
        elseif ($line -match "aws_session_token\s*=\s*(.+)") {
            $SessionToken = $Matches[1].Trim()
        }
    }
}

# ---------------------------------------------------------
# Validar que se obtuvieron las 3 claves
# ---------------------------------------------------------
if (-not $AccessKey -or -not $SecretKey -or -not $SessionToken) {
    Write-Host "[ERROR] No se pudieron parsear las credenciales. Verifica el formato." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Credenciales parseadas: $($AccessKey.Substring(0, [Math]::Min(10, $AccessKey.Length)))..." -ForegroundColor Green

# ---------------------------------------------------------
# Actualizar credentials.tf
# ---------------------------------------------------------
$credFile = Join-Path $ScriptDir "credentials.tf"

$content = @"
# ARCHIVO LOCAL — NO SE SUBE A GITHUB (está en .gitignore)
# Actualiza estos valores al inicio de cada sesión en AWS Academy Learner Lab.
#
# Cómo obtener las credenciales:
#   1. Abre AWS Academy Learner Lab
#   2. Haz clic en "AWS Details" (arriba a la derecha)
#   3. Ejecuta: .\update-credentials.ps1  y pega las 3 líneas
#
# IMPORTANTE: Las credenciales de AWS Academy expiran cada ~4 horas.

locals {
  aws_access_key    = "$AccessKey"
  aws_secret_key    = "$SecretKey"
  aws_session_token = "$SessionToken"
}
"@

Set-Content -Path $credFile -Value $content -Encoding UTF8
Write-Host "[OK] credentials.tf actualizado" -ForegroundColor Green

# ---------------------------------------------------------
# Actualizar variables de entorno del proceso actual
# (para que aws cli funcione en esta sesión de PowerShell)
# ---------------------------------------------------------
$env:AWS_ACCESS_KEY_ID     = $AccessKey
$env:AWS_SECRET_ACCESS_KEY = $SecretKey
$env:AWS_SESSION_TOKEN     = $SessionToken
$env:AWS_DEFAULT_REGION    = "us-east-1"

Write-Host "[OK] Variables de entorno AWS configuradas para esta sesión" -ForegroundColor Green

# ---------------------------------------------------------
# Verificar que las credenciales son válidas
# ---------------------------------------------------------
Write-Host ""
Write-Host "Verificando credenciales con AWS STS..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    Write-Host "[OK] Cuenta: $($identity.Account)" -ForegroundColor Green
    Write-Host "[OK] Usuario: $($identity.Arn)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credenciales validas. Puedes ejecutar el deploy." -ForegroundColor Green
    Write-Host "  .\master-deploy.ps1" -ForegroundColor Cyan
}
catch {
    Write-Host "[WARN] No se pudo verificar con STS. Verifica que las credenciales sean correctas." -ForegroundColor Yellow
}
