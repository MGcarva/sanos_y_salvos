# =============================================================
# master-deploy.ps1 — Script maestro de despliegue
# "Sanos y Salvos" en AWS Academy
# =============================================================
# TIEMPO ESTIMADO: 45-60 minutos (primera vez)
#                   15-20 minutos (imágenes Docker ya construidas localmente)
#
# PREREQUISITOS ANTES DE EJECUTAR:
#   1. Ejecutar .\update-credentials.ps1  (credenciales AWS Academy vigentes)
#   2. Tener Docker Desktop corriendo
#   3. Tener Terraform instalado (terraform -v)
#   4. Tener AWS CLI instalado (aws --version)
#   5. Haber creado un Key Pair llamado "sanos-y-salvos-key" en la consola AWS
#      y descargado el archivo .pem en esta carpeta
#   6. El código de los microservicios estar en ../Sanos-y-Salvos/
#
# USO:
#   .\master-deploy.ps1                          # Deploy completo
#   .\master-deploy.ps1 -SkipBuild               # Saltar build de imágenes (ya están en ECR)
#   .\master-deploy.ps1 -SkipTerraform           # Saltar terraform (infra ya existe)
#   .\master-deploy.ps1 -SkipFrontend            # Saltar deploy de frontend
# =============================================================

param(
    [switch]$SkipBuild     = $false,
    [switch]$SkipTerraform = $false,
    [switch]$SkipFrontend  = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AppDir      = Resolve-Path "$ScriptDir\..\Sanos-y-Salvos" -ErrorAction SilentlyContinue
$Region      = "us-east-1"
$StartTime   = Get-Date

$services = @("auth-service", "ms-mascotas", "ms-geolocalizacion", "ms-coincidencias", "bff-service")

function Write-Step { param($msg) Write-Host "" ; Write-Host ">>> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red ; exit 1 }
function Write-Info { param($msg) Write-Host "  $msg" -ForegroundColor Gray }
function Elapsed    { [int](((Get-Date) - $StartTime).TotalMinutes) }

# =============================================================
# ETAPA 0 — Verificar prerequisitos
# =============================================================
Write-Step "ETAPA 0 — Verificando prerequisitos"

foreach ($tool in @("aws", "terraform", "docker")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Fail "$tool no encontrado. Instálalo antes de continuar."
    }
    Write-OK "$tool disponible"
}

# Verificar credenciales AWS
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-OK "Credenciales AWS válidas - Cuenta: $($identity.Account)"
    $AccountId = $identity.Account
}
catch {
    Write-Fail "Credenciales AWS inválidas o expiradas. Ejecuta .\update-credentials.ps1 primero."
}

# Verificar Docker corriendo
docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker no está corriendo. Inicia Docker Desktop." }
Write-OK "Docker corriendo"

# Verificar directorio de microservicios
if (-not $AppDir -or -not (Test-Path $AppDir)) {
    Write-Fail "No se encontró el directorio de microservicios en $AppDir"
}
Write-OK "Directorio de microservicios: $AppDir"

# =============================================================
# ETAPA 1 — Terraform (crear infraestructura)
# =============================================================
if (-not $SkipTerraform) {
    Write-Step "ETAPA 1 — Terraform init + apply (~10-15 min)"
    Set-Location $ScriptDir

    Write-Info "terraform init..."
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform init falló" }

    Write-Info "terraform apply..."
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform apply falló" }

    Write-OK "Infraestructura creada ($(Elapsed) min)"
}
else {
    Write-Step "ETAPA 1 — Terraform [SKIPPED]"
}

# =============================================================
# Leer outputs de Terraform
# =============================================================
Write-Step "Leyendo outputs de Terraform"
Set-Location $ScriptDir

$tfOutput = terraform output -json | ConvertFrom-Json
$AlbDns       = $tfOutput.alb_dns.value
$EcrRegistry  = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$Ec2Ip        = $tfOutput.ec2_public_ip.value
$S3Bucket     = "sanos-y-salvos-frontend-$AccountId"

Write-Info "ALB DNS     : $AlbDns"
Write-Info "ECR Registry: $EcrRegistry"
Write-Info "EC2 IP      : $Ec2Ip"
Write-Info "S3 Frontend : $S3Bucket"

# =============================================================
# ETAPA 2 — S3 bucket para fotos (si no existe)
# =============================================================
Write-Step "ETAPA 2 — Crear S3 bucket para fotos"
$photoBucket = "sanos-y-salvos-mascotas-fotos"

aws s3api head-bucket --bucket $photoBucket 2>$null
if ($LASTEXITCODE -ne 0) {
    aws s3api create-bucket --bucket $photoBucket --region $Region
    if ($LASTEXITCODE -eq 0) { Write-OK "Bucket $photoBucket creado" }
    else { Write-Info "[WARN] No se pudo crear bucket de fotos, continúa..." }
}
else {
    Write-OK "Bucket $photoBucket ya existe"
}

# =============================================================
# ETAPA 3 — Build y push de imágenes Docker
# =============================================================
if (-not $SkipBuild) {
    Write-Step "ETAPA 3 — Build y push de imágenes Docker (~20-30 min)"

    # Login a ECR
    aws ecr get-login-password --region $Region | `
        docker login --username AWS --password-stdin "$EcrRegistry"
    Write-OK "ECR login exitoso"

    Set-Location $AppDir

    # Build del proyecto (Maven compila todos los servicios)
    Write-Info "Compilando todos los microservicios con Maven..."
    mvn clean package -DskipTests --no-transfer-progress -q
    if ($LASTEXITCODE -ne 0) { Write-Fail "Maven build falló" }
    Write-OK "Maven build exitoso ($(Elapsed) min)"

    # Build y push de cada servicio
    foreach ($svc in $services) {
        $imgName  = "$EcrRegistry/sanos-y-salvos/$svc`:latest"
        $svcDir   = Join-Path $AppDir $svc

        if (-not (Test-Path $svcDir)) {
            Write-Info "[WARN] Directorio $svcDir no encontrado, saltando..."
            continue
        }

        Write-Info "Building $svc..."
        docker build -t $imgName $svcDir -q
        if ($LASTEXITCODE -ne 0) { Write-Fail "docker build $svc falló" }

        Write-Info "Pushing $svc a ECR..."
        docker push $imgName
        if ($LASTEXITCODE -ne 0) { Write-Fail "docker push $svc falló" }

        Write-OK "$svc pushed ($(Elapsed) min)"
    }
}
else {
    Write-Step "ETAPA 3 — Build de imágenes [SKIPPED] - Asegúrate de haberlas pushado antes"

    # Solo login y retag
    aws ecr get-login-password --region $Region | `
        docker login --username AWS --password-stdin "$EcrRegistry"

    Write-Info "Haciendo push de imágenes locales existentes..."
    foreach ($svc in $services) {
        $imgName = "$EcrRegistry/sanos-y-salvos/$svc`:latest"
        docker tag "sanos-y-salvos/$svc`:latest" $imgName 2>$null
        docker push $imgName 2>$null
        if ($LASTEXITCODE -eq 0) { Write-OK "$svc pushed" }
        else { Write-Info "[WARN] $svc - imagen local no encontrada o push falló" }
    }
}

# =============================================================
# ETAPA 4 — Esperar que el EC2 arranque y los servicios estén UP
# =============================================================
Write-Step "ETAPA 4 — Esperando que EC2 y microservicios arranquen"
Write-Info "El EC2 instala Docker y levanta 5 JVMs. Esperar ~3-4 min..."

$maxWait   = 300   # 5 minutos máximo
$interval  = 15    # check cada 15 segundos
$waited    = 0
$bffUrl    = "http://${Ec2Ip}:8080/actuator/health"

Write-Info "Polling $bffUrl cada $interval seg (máximo $maxWait seg)..."

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds $interval
    $waited += $interval
    try {
        $resp = Invoke-WebRequest -Uri $bffUrl -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-OK "BFF service UP después de $waited segundos!"
            break
        }
    }
    catch { Write-Info "  Esperando... ($waited/$maxWait seg)" }
}

if ($waited -ge $maxWait) {
    Write-Host "[WARN] BFF no respondió en $maxWait seg. Verifica logs en el EC2:" -ForegroundColor Yellow
    Write-Info "  ssh ec2-user@$Ec2Ip -i sanos-y-salvos-key.pem"
    Write-Info "  tail -f /var/log/sanos-deploy.log"
}

# =============================================================
# ETAPA 5 — Deploy del frontend a S3
# =============================================================
if (-not $SkipFrontend) {
    Write-Step "ETAPA 5 — Deploy del frontend a S3 (~5 min)"

    $frontendDir = Join-Path $AppDir "frontend"
    if (-not (Test-Path $frontendDir)) {
        Write-Info "[WARN] Directorio frontend no encontrado en $frontendDir"
    }
    else {
        Set-Location $frontendDir

        # Crear .env.production con la URL del ALB
        $envContent = "VITE_API_BASE_URL=http://$AlbDns/api"
        Set-Content -Path ".env.production" -Value $envContent
        Write-Info "VITE_API_BASE_URL=http://$AlbDns/api"

        # Build del frontend
        npm install --silent
        npm run build
        if ($LASTEXITCODE -ne 0) { Write-Fail "npm run build falló" }
        Write-OK "Frontend build exitoso"

        # Crear bucket S3 para frontend
        aws s3api head-bucket --bucket $S3Bucket 2>$null
        if ($LASTEXITCODE -ne 0) {
            aws s3api create-bucket --bucket $S3Bucket --region $Region
        }

        # Configurar hosting estático
        aws s3api delete-public-access-block --bucket $S3Bucket
        aws s3api put-bucket-policy --bucket $S3Bucket --policy @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$S3Bucket/*"
  }]
}
"@
        aws s3 website "s3://$S3Bucket" --index-document index.html --error-document index.html

        # Subir archivos
        aws s3 sync dist/ "s3://$S3Bucket" --delete `
            --cache-control "no-cache" --exclude "assets/*"
        aws s3 sync dist/assets/ "s3://$S3Bucket/assets/" `
            --cache-control "max-age=31536000" --delete

        Write-OK "Frontend desplegado en S3 ($(Elapsed) min)"
        Write-Info "URL frontend: http://$S3Bucket.s3-website-us-east-1.amazonaws.com"
    }
}
else {
    Write-Step "ETAPA 5 — Frontend [SKIPPED]"
}

# =============================================================
# ETAPA 6 — Smoke test final
# =============================================================
Write-Step "ETAPA 6 — Smoke test"
Set-Location $ScriptDir
& .\smoke-test.ps1 -AlbDns $AlbDns -Ec2Ip $Ec2Ip

# =============================================================
# RESUMEN FINAL
# =============================================================
$totalMin = [int](((Get-Date) - $StartTime).TotalMinutes)
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  DEPLOY COMPLETADO en $totalMin minutos" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  APLICACION   : http://$AlbDns" -ForegroundColor Cyan
Write-Host "  FRONTEND S3  : http://$S3Bucket.s3-website-us-east-1.amazonaws.com" -ForegroundColor Cyan
Write-Host "  BFF DIRECTO  : http://$Ec2Ip`:8080" -ForegroundColor Cyan
Write-Host "  AUTH DIRECTO : http://$Ec2Ip`:8081" -ForegroundColor Cyan
Write-Host ""
Write-Host "  SSH al EC2   : ssh ec2-user@$Ec2Ip -i sanos-y-salvos-key.pem" -ForegroundColor Gray
Write-Host "  Logs deploy  : (en EC2) tail -f /var/log/sanos-deploy.log" -ForegroundColor Gray
Write-Host "  Logs BFF     : (en EC2) docker logs bff-service -f" -ForegroundColor Gray
Write-Host ""
Write-Host "  CUANDO TERMINES LA PRESENTACION:" -ForegroundColor Yellow
Write-Host "  terraform destroy -auto-approve  (destruye todo)" -ForegroundColor Gray
Write-Host ""
