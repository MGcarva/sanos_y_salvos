# ================================================================
# INIT DATABASE — Sanos y Salvos
# ================================================================
# Crea las 4 bases de datos en RDS PostgreSQL y habilita extensiones.
# Las TABLAS las crea Hibernate automaticamente al arrancar los servicios.
#
# Estrategia:
#   1. Obtiene tu IP publica actual
#   2. Abre temporalmente el SG de RDS para tu IP (puerto 5432)
#   3. Hace RDS publicamente accesible via AWS CLI
#   4. Ejecuta init-db.sql usando Docker (psql)
#   5. Cierra el acceso (revierte todo)
#
# Requisitos:
#   - Docker Desktop corriendo
#   - AWS CLI instalado
#   - terraform apply ya ejecutado
#   - credentials.tf actualizado
# ================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$REGION       = "us-east-1"
$PROYECTO     = "sanos-y-salvos"
$SCRIPT_DIR   = $PSScriptRoot
$SQL_FILE     = Join-Path $SCRIPT_DIR "init-db.sql"

# ================================================================
# 1. LEER CREDENCIALES
# ================================================================
Write-Host ""
Write-Host "==> [1/7] Leyendo credenciales..." -ForegroundColor Cyan

$credContent  = Get-Content (Join-Path $SCRIPT_DIR "credentials.tf") -Raw
$accessKey    = [regex]::Match($credContent, 'aws_access_key\s*=\s*"([^"]+)"').Groups[1].Value
$secretKey    = [regex]::Match($credContent, 'aws_secret_key\s*=\s*"([^"]+)"').Groups[1].Value
$sessionToken = [regex]::Match($credContent, 'aws_session_token\s*=\s*"([^"]+)"').Groups[1].Value

if (-not $accessKey) { Write-Host "ERROR: No se leyeron credenciales" -ForegroundColor Red; exit 1 }

$env:AWS_ACCESS_KEY_ID     = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_SESSION_TOKEN     = $sessionToken
$env:AWS_DEFAULT_REGION    = $REGION

Write-Host "    OK" -ForegroundColor Green

# ================================================================
# 2. LEER OUTPUTS DE TERRAFORM
# ================================================================
Write-Host ""
Write-Host "==> [2/7] Leyendo outputs de Terraform..." -ForegroundColor Cyan

Push-Location $SCRIPT_DIR
$tfOutputs = terraform output -json | ConvertFrom-Json
Pop-Location

$RDS_HOST    = $tfOutputs.rds_host.value
$DB_USER     = "sanosadmin"
$DB_PASS     = "SanosYSalvos2026!"

# Obtener el ID del SG de RDS
$RDS_SG_ID = (aws rds describe-db-instances `
    --db-instance-identifier "$PROYECTO-postgres" `
    --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" `
    --output text 2>&1).Trim()

Write-Host "    RDS Host    : $RDS_HOST" -ForegroundColor Green
Write-Host "    RDS SG ID   : $RDS_SG_ID" -ForegroundColor Green

# ================================================================
# 3. OBTENER IP PUBLICA Y ABRIR ACCESO TEMPORAL
# ================================================================
Write-Host ""
Write-Host "==> [3/7] Abriendo acceso temporal a RDS desde tu IP..." -ForegroundColor Cyan

$MY_IP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction Stop).Trim()
$MY_CIDR = "$MY_IP/32"
Write-Host "    Tu IP publica: $MY_IP" -ForegroundColor Green

# Agregar regla de ingreso al SG de RDS
aws ec2 authorize-security-group-ingress `
    --group-id $RDS_SG_ID `
    --protocol tcp `
    --port 5432 `
    --cidr $MY_CIDR `
    --region $REGION 2>&1 | Out-Null

Write-Host "    Regla de SG agregada" -ForegroundColor Green

# ================================================================
# 4. HACER RDS PUBLICAMENTE ACCESIBLE
# ================================================================
Write-Host ""
Write-Host "==> [4/7] Habilitando acceso publico en RDS (espera ~60s)..." -ForegroundColor Cyan

aws rds modify-db-instance `
    --db-instance-identifier "$PROYECTO-postgres" `
    --publicly-accessible `
    --apply-immediately | Out-Null

# Esperar a que RDS quede en estado 'available'
Write-Host "    Esperando que RDS quede disponible..." -ForegroundColor Yellow
$intentos = 0
do {
    Start-Sleep -Seconds 15
    $intentos++
    $estado = (aws rds describe-db-instances `
        --db-instance-identifier "$PROYECTO-postgres" `
        --query "DBInstances[0].DBInstanceStatus" `
        --output text 2>&1).Trim()
    Write-Host "    Estado: $estado (intento $intentos/20)" -ForegroundColor Gray
} while ($estado -ne "available" -and $intentos -lt 20)

if ($estado -ne "available") {
    Write-Host "TIMEOUT: RDS no quedo disponible a tiempo" -ForegroundColor Red
    # Revertir SG antes de salir
    aws ec2 revoke-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 5432 --cidr $MY_CIDR --region $REGION 2>&1 | Out-Null
    exit 1
}

# Obtener el endpoint actualizado (puede cambiar al hacer publicamente accesible)
$RDS_HOST = (aws rds describe-db-instances `
    --db-instance-identifier "$PROYECTO-postgres" `
    --query "DBInstances[0].Endpoint.Address" `
    --output text 2>&1).Trim()

Write-Host "    RDS disponible en: $RDS_HOST" -ForegroundColor Green

# ================================================================
# 5. EJECUTAR init-db.sql VIA DOCKER
# ================================================================
Write-Host ""
Write-Host "==> [5/7] Ejecutando init-db.sql contra RDS..." -ForegroundColor Cyan

# Convertir ruta Windows a formato Docker
$sqlFileDocker = $SQL_FILE -replace "\\", "/" -replace "^([A-Z]):", '/$1'
$sqlFileDocker = $sqlFileDocker.ToLower() -replace "^/([a-z])/", '/$1:/'

# Alternativa: usar variable de entorno para la password
$env:PGPASSWORD = $DB_PASS

docker run --rm `
    -v "${SQL_FILE}:/init-db.sql" `
    -e "PGPASSWORD=$DB_PASS" `
    postgres:15-alpine `
    psql -h $RDS_HOST -U $DB_USER -d postgres -f /init-db.sql

if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: Algunos comandos del SQL fallaron (puede que las BDs ya existan)" -ForegroundColor Yellow
} else {
    Write-Host "    SQL ejecutado OK" -ForegroundColor Green
}

# ================================================================
# 6. VERIFICAR BASES DE DATOS CREADAS
# ================================================================
Write-Host ""
Write-Host "==> [6/7] Verificando bases de datos..." -ForegroundColor Cyan

docker run --rm `
    -e "PGPASSWORD=$DB_PASS" `
    postgres:15-alpine `
    psql -h $RDS_HOST -U $DB_USER -d postgres -c "\l" --tuples-only 2>&1 |
    Where-Object { $_ -match "auth_db|mascotas_db|geolocalizacion_db|coincidencias_db" } |
    ForEach-Object { Write-Host "    BD encontrada: $_" -ForegroundColor Green }

# ================================================================
# 7. REVERTIR ACCESO TEMPORAL
# ================================================================
Write-Host ""
Write-Host "==> [7/7] Revirtiendo acceso publico (seguridad)..." -ForegroundColor Cyan

# Quitar regla del SG
aws ec2 revoke-security-group-ingress `
    --group-id $RDS_SG_ID `
    --protocol tcp `
    --port 5432 `
    --cidr $MY_CIDR `
    --region $REGION 2>&1 | Out-Null

# Revertir publicly-accessible
aws rds modify-db-instance `
    --db-instance-identifier "$PROYECTO-postgres" `
    --no-publicly-accessible `
    --apply-immediately | Out-Null

Write-Host "    Acceso publico removido" -ForegroundColor Green

# ================================================================
# RESUMEN
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  BASES DE DATOS INICIALIZADAS" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Bases de datos creadas:" -ForegroundColor White
Write-Host "    auth_db           -> tablas creadas por auth-service al arrancar"      -ForegroundColor Gray
Write-Host "    mascotas_db       -> tablas creadas por ms-mascotas al arrancar"       -ForegroundColor Gray
Write-Host "    geolocalizacion_db-> tablas creadas por ms-geolocalizacion al arrancar" -ForegroundColor Gray
Write-Host "    coincidencias_db  -> tablas creadas por ms-coincidencias al arrancar"  -ForegroundColor Gray
Write-Host ""
Write-Host "  Siguiente paso: desplegar los microservicios." -ForegroundColor Yellow
Write-Host ""
