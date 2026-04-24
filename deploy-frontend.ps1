# ================================================================
# DEPLOY FRONTEND — Sanos y Salvos (S3 Static Website)
# ================================================================
# Ejecutar desde c:\terraform-aws con:
#   .\deploy-frontend.ps1
#
# Requisitos:
#   - Docker Desktop corriendo
#   - AWS CLI instalado
#   - terraform apply ya ejecutado (outputs disponibles)
#   - credentials.tf actualizado con la sesion actual de Academy
# ================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ================================================================
# 0. CONFIGURACION
# ================================================================
$FRONTEND_PATH = "C:\Users\prueba\Desktop\Sanos y Salvos\sanos-y-salvos\frontend"
$REGION        = "us-east-1"
$PROYECTO      = "sanos-y-salvos"

# ================================================================
# 1. LEER CREDENCIALES DESDE credentials.tf
# ================================================================
Write-Host ""
Write-Host "==> [1/6] Leyendo credenciales desde credentials.tf..." -ForegroundColor Cyan

$credFile    = Join-Path $PSScriptRoot "credentials.tf"
$credContent = Get-Content $credFile -Raw

$accessKey    = [regex]::Match($credContent, 'aws_access_key\s*=\s*"([^"]+)"').Groups[1].Value
$secretKey    = [regex]::Match($credContent, 'aws_secret_key\s*=\s*"([^"]+)"').Groups[1].Value
$sessionToken = [regex]::Match($credContent, 'aws_session_token\s*=\s*"([^"]+)"').Groups[1].Value

if (-not $accessKey -or -not $secretKey -or -not $sessionToken) {
    Write-Host "ERROR: No se pudieron leer las credenciales de credentials.tf" -ForegroundColor Red
    exit 1
}

$env:AWS_ACCESS_KEY_ID     = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_SESSION_TOKEN     = $sessionToken
$env:AWS_DEFAULT_REGION    = $REGION

Write-Host "    Credenciales cargadas OK" -ForegroundColor Green

# ================================================================
# 2. LEER OUTPUTS DE TERRAFORM
# ================================================================
Write-Host ""
Write-Host "==> [2/6] Leyendo outputs de Terraform..." -ForegroundColor Cyan

Push-Location $PSScriptRoot
try {
    $tfOutputs = terraform output -json | ConvertFrom-Json
} catch {
    Write-Host "ERROR: No se pudo leer terraform output. Ejecuta 'terraform apply' primero." -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

$ALB_DNS     = $tfOutputs.alb_dns.value
$VITE_API_URL = "http://$ALB_DNS/api"

# Obtener account ID para nombre unico del bucket
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text 2>&1).Trim()
if (-not ($ACCOUNT_ID -match '^\d+$')) {
    Write-Host "ERROR: No se pudo obtener el Account ID. Verifica las credenciales." -ForegroundColor Red
    exit 1
}

$BUCKET_NAME = "$PROYECTO-frontend-$ACCOUNT_ID"

Write-Host "    ALB DNS       : $ALB_DNS" -ForegroundColor Green
Write-Host "    VITE_API_URL  : $VITE_API_URL" -ForegroundColor Green
Write-Host "    S3 Bucket     : $BUCKET_NAME" -ForegroundColor Green

# ================================================================
# 3. DOCKER BUILD + EXTRAER dist/
# ================================================================
Write-Host ""
Write-Host "==> [3/6] Construyendo frontend con Docker (stage builder)..." -ForegroundColor Cyan

# Limpiar contenedor anterior si existe
docker rm -f dist-extract 2>$null | Out-Null

# Build solo la etapa 'builder' con la URL del ALB inyectada
docker build --target builder `
    --build-arg "VITE_API_URL=$VITE_API_URL" `
    -t frontend-builder:tmp `
    $FRONTEND_PATH

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: docker build fallo" -ForegroundColor Red
    exit 1
}

# Extraer la carpeta dist/ del contenedor a una carpeta local temporal
$distLocal = Join-Path $env:TEMP "sanos-frontend-dist"
if (Test-Path $distLocal) { Remove-Item $distLocal -Recurse -Force }

docker create --name dist-extract frontend-builder:tmp | Out-Null
docker cp "dist-extract:/app/dist/." $distLocal
docker rm dist-extract | Out-Null
docker rmi frontend-builder:tmp | Out-Null

# Verificar que index.html exista como prueba del build exitoso
if (-not (Test-Path "$distLocal\index.html")) {
    Write-Host "ERROR: No se encontro index.html en $distLocal" -ForegroundColor Red
    Write-Host "       Archivos presentes:" -ForegroundColor Gray
    Get-ChildItem $distLocal -ErrorAction SilentlyContinue | Select-Object Name | Format-Table -HideTableHeaders
    exit 1
}

Write-Host "    Build y extraccion OK -> $distLocal" -ForegroundColor Green

# ================================================================
# 4. CREAR Y CONFIGURAR BUCKET S3
# ================================================================
Write-Host ""
Write-Host "==> [4/6] Configurando bucket S3 '$BUCKET_NAME'..." -ForegroundColor Cyan

# Crear bucket (idempotente: no falla si ya existe y es tuyo)
$bucketCheck = (aws s3api head-bucket --bucket $BUCKET_NAME 2>&1)
if ($LASTEXITCODE -ne 0) {
    Write-Host "    Creando bucket..." -ForegroundColor Yellow
    aws s3 mb "s3://$BUCKET_NAME" --region $REGION | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: No se pudo crear el bucket S3" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "    Bucket ya existe" -ForegroundColor Green
}

# Deshabilitar bloqueo de acceso publico
aws s3api put-public-access-block `
    --bucket $BUCKET_NAME `
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" | Out-Null

# Politica de lectura publica
$bucketPolicy = '{"Version":"2012-10-17","Statement":[{"Sid":"PublicRead","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::' + $BUCKET_NAME + '/*"}]}'
$policyFile = Join-Path $env:TEMP "bucket-policy.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($policyFile, $bucketPolicy, $utf8NoBom)

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "file://$policyFile" | Out-Null

# Habilitar static website hosting
aws s3 website "s3://$BUCKET_NAME" --index-document index.html --error-document index.html | Out-Null

Write-Host "    Bucket configurado OK" -ForegroundColor Green

# ================================================================
# 5. SUBIR ARCHIVOS A S3
# ================================================================
Write-Host ""
Write-Host "==> [5/6] Subiendo archivos a S3..." -ForegroundColor Cyan

# Assets (JS/CSS/fonts): cache de 1 año
aws s3 sync "$distLocal" "s3://$BUCKET_NAME" `
    --delete `
    --exclude "index.html" `
    --cache-control "public,max-age=31536000,immutable" `
    --region $REGION

# index.html: sin cache para que siempre sirva la version nueva
aws s3 cp "$distLocal\index.html" "s3://$BUCKET_NAME/index.html" `
    --cache-control "no-cache,no-store,must-revalidate" `
    --content-type "text/html" `
    --region $REGION

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: aws s3 sync fallo" -ForegroundColor Red
    exit 1
}
Write-Host "    Archivos subidos OK" -ForegroundColor Green

# ================================================================
# 6. RESUMEN
# ================================================================
$S3_URL = "http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  DEPLOY COMPLETADO" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Frontend URL : $S3_URL" -ForegroundColor White
Write-Host "  API URL      : $VITE_API_URL" -ForegroundColor White
Write-Host ""
Write-Host "  Abre esta URL en el navegador para verificar." -ForegroundColor Yellow
Write-Host ""
