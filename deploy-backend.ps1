# ================================================================
# DEPLOY BACKEND — Sanos y Salvos
# ================================================================
# Construye las imagenes Docker de los 5 microservicios, las sube
# a ECR y lanza una instancia EC2 (t3.medium) que las ejecuta.
#
# Por que EC2 y no ECS:
#   AWS Academy bloquea ecs:CreateCluster y ecs:RegisterTaskDefinition.
#   La solucion es lanzar un EC2 con Docker y registrar su IP privada
#   directamente en el target group del ALB (target_type="ip").
#
# Servicios desplegados:
#   RabbitMQ (Docker en EC2)   - mensajeria asincrona entre servicios
#   auth-service   :8081       - autenticacion JWT + Redis
#   ms-mascotas    :8082       - CRUD de reportes + S3
#   ms-geolocalizacion :8083   - ubicaciones + clustering
#   ms-coincidencias   :8084   - matching algoritmo
#   bff-service    :8080       - gateway -> ALB -> frontend
#
# Flujo de trafico:
#   Internet -> ALB (/api/*) -> EC2:8080 (bff) -> contenedores internos
#
# Requisitos:
#   - Docker Desktop corriendo
#   - AWS CLI instalado
#   - terraform apply ya ejecutado
#   - credentials.tf actualizado con las credenciales actuales de Academy
#   - Codigo fuente en: c:\Users\prueba\Desktop\Sanos y Salvos\sanos-y-salvos
# ================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ================================================================
# CONFIGURACION
# ================================================================
$REGION       = "us-east-1"
$ACCOUNT_ID   = "236373526017"
$PROYECTO     = "sanos-y-salvos"
$ECR_REGISTRY = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
$SOURCE_DIR   = "c:\Users\prueba\Desktop\Sanos y Salvos\sanos-y-salvos"
$SCRIPT_DIR   = $PSScriptRoot
$KEY_NAME     = "$PROYECTO-backend-key"
$KEY_FILE     = Join-Path $SCRIPT_DIR "$KEY_NAME.pem"
$INSTANCE_NAME = "$PROYECTO-backend"

# ================================================================
# 1. LEER CREDENCIALES
# ================================================================
Write-Host ""
Write-Host "==> [1/10] Leyendo credenciales de Academy..." -ForegroundColor Cyan

$credContent  = Get-Content (Join-Path $SCRIPT_DIR "credentials.tf") -Raw
$accessKey    = [regex]::Match($credContent, 'aws_access_key\s*=\s*"([^"]+)"').Groups[1].Value
$secretKey    = [regex]::Match($credContent, 'aws_secret_key\s*=\s*"([^"]+)"').Groups[1].Value
$sessionToken = [regex]::Match($credContent, 'aws_session_token\s*=\s*"([^"]+)"').Groups[1].Value

if (-not $accessKey) { Write-Host "ERROR: No se leyeron credenciales de credentials.tf" -ForegroundColor Red; exit 1 }

$env:AWS_ACCESS_KEY_ID     = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_SESSION_TOKEN     = $sessionToken
$env:AWS_DEFAULT_REGION    = $REGION

Write-Host "    OK (key: $($accessKey.Substring(0,8))...)" -ForegroundColor Green

# ================================================================
# 2. LEER OUTPUTS DE TERRAFORM
# ================================================================
Write-Host ""
Write-Host "==> [2/10] Leyendo outputs de Terraform..." -ForegroundColor Cyan

Push-Location $SCRIPT_DIR
$tfOutputsJson = terraform output -json
Pop-Location

$tfOutputs = $tfOutputsJson | ConvertFrom-Json

$RDS_HOST        = $tfOutputs.rds_host.value
$REDIS_HOST      = $tfOutputs.redis_host.value
$ALB_DNS         = $tfOutputs.alb_dns.value
$TG_BFF_ARN      = $tfOutputs.tg_bff_arn.value
$SG_BFF_ID       = $tfOutputs.sg_bff_id.value
$SG_MICROS_ID    = $tfOutputs.sg_microservicios_id.value
$FRONTEND_URL    = "http://sanos-y-salvos-frontend-$ACCOUNT_ID.s3-website-$REGION.amazonaws.com"

Write-Host "    RDS Host    : $RDS_HOST" -ForegroundColor Green
Write-Host "    Redis Host  : $REDIS_HOST" -ForegroundColor Green
Write-Host "    ALB DNS     : $ALB_DNS" -ForegroundColor Green
Write-Host "    TG BFF ARN  : $TG_BFF_ARN" -ForegroundColor Green

# ================================================================
# 3. LEER SECRETOS DE SECRETS MANAGER
# ================================================================
Write-Host ""
Write-Host "==> [3/10] Leyendo secretos de Secrets Manager..." -ForegroundColor Cyan

$dbSecret = (aws secretsmanager get-secret-value `
    --secret-id "$PROYECTO/db-credentials" `
    --query "SecretString" `
    --output text 2>&1) | ConvertFrom-Json

$redisSecret = (aws secretsmanager get-secret-value `
    --secret-id "$PROYECTO/redis-credentials" `
    --query "SecretString" `
    --output text 2>&1) | ConvertFrom-Json

$rabbitSecret = (aws secretsmanager get-secret-value `
    --secret-id "$PROYECTO/rabbitmq-credentials" `
    --query "SecretString" `
    --output text 2>&1) | ConvertFrom-Json

$jwtSecret = (aws secretsmanager get-secret-value `
    --secret-id "$PROYECTO/jwt-secret" `
    --query "SecretString" `
    --output text 2>&1) | ConvertFrom-Json

$DB_USER      = $dbSecret.username
$DB_PASS      = $dbSecret.password
$REDIS_PASS   = $redisSecret.password
$RABBIT_USER  = $rabbitSecret.username
$RABBIT_PASS  = $rabbitSecret.password

# El jwt-secret puede ser un JSON con clave "secret" o directamente el string
if ($jwtSecret -is [PSCustomObject] -and $jwtSecret.PSObject.Properties['secret']) {
    $JWT_SECRET = $jwtSecret.secret
} else {
    $JWT_SECRET = $jwtSecret.ToString()
}

Write-Host "    DB User     : $DB_USER" -ForegroundColor Green
Write-Host "    Rabbit User : $RABBIT_USER" -ForegroundColor Green
Write-Host "    Secretos leidos OK" -ForegroundColor Green

# ================================================================
# 4. CREAR BUCKET S3 PARA FOTOS DE MASCOTAS
# ================================================================
Write-Host ""
Write-Host "==> [4/10] Verificando bucket S3 para fotos de mascotas..." -ForegroundColor Cyan

$MASCOTAS_BUCKET = "sanos-y-salvos-mascotas-fotos"

$bucketExists = aws s3api head-bucket --bucket $MASCOTAS_BUCKET 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "    Creando bucket $MASCOTAS_BUCKET..." -ForegroundColor Yellow
    aws s3api create-bucket --bucket $MASCOTAS_BUCKET --region $REGION 2>&1 | Out-Null
    # Deshabilitar bloqueo de acceso publico (necesario para imagenes publicas)
    aws s3api put-public-access-block --bucket $MASCOTAS_BUCKET `
        --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" 2>&1 | Out-Null
    # Politica de lectura publica para las fotos
    $bucketPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::' + $MASCOTAS_BUCKET + '/*"}]}'
    $tempPolicy = Join-Path $env:TEMP "mascotas-bucket-policy.json"
    [System.IO.File]::WriteAllText($tempPolicy, $bucketPolicy, (New-Object System.Text.UTF8Encoding $false))
    aws s3api put-bucket-policy --bucket $MASCOTAS_BUCKET --policy "file://$tempPolicy" 2>&1 | Out-Null
    Write-Host "    Bucket creado OK" -ForegroundColor Green
} else {
    Write-Host "    Bucket ya existe OK" -ForegroundColor Green
}

# ================================================================
# 5. LOGIN EN ECR Y BUILD + PUSH DE IMAGENES
# ================================================================
Write-Host ""
Write-Host "==> [5/10] Login en ECR..." -ForegroundColor Cyan

$ecrPassword = aws ecr get-login-password --region $REGION
$loginResult = docker login --username AWS --password $ecrPassword $ECR_REGISTRY 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Login ECR fallido: $loginResult" -ForegroundColor Red; exit 1 }
Write-Host "    Login ECR OK" -ForegroundColor Green

# Verificar que el directorio fuente existe
if (-not (Test-Path $SOURCE_DIR)) {
    Write-Host "ERROR: No se encontro el codigo fuente en: $SOURCE_DIR" -ForegroundColor Red
    Write-Host "       Ajusta la variable SOURCE_DIR al inicio del script" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==> [6/10] Construyendo y subiendo imagenes Docker..." -ForegroundColor Cyan
Write-Host "    Directorio fuente: $SOURCE_DIR" -ForegroundColor Gray
Write-Host "    Nota: cada build descarga dependencias Maven (~3-5 min por servicio)" -ForegroundColor Yellow

# Servicios con su Dockerfile relativo a la raiz del repo
$servicios = @(
    @{ Nombre = "auth-service";       Puerto = 8081; Dockerfile = "auth-service/Dockerfile" }
    @{ Nombre = "ms-mascotas";        Puerto = 8082; Dockerfile = "ms-mascotas/Dockerfile" }
    @{ Nombre = "ms-geolocalizacion"; Puerto = 8083; Dockerfile = "ms-geolocalizacion/Dockerfile" }
    @{ Nombre = "ms-coincidencias";   Puerto = 8084; Dockerfile = "ms-coincidencias/Dockerfile" }
    @{ Nombre = "bff-service";        Puerto = 8080; Dockerfile = "bff-service/Dockerfile" }
)

Push-Location $SOURCE_DIR
foreach ($svc in $servicios) {
    $imageName = "$ECR_REGISTRY/$PROYECTO/$($svc.Nombre):latest"
    Write-Host ""
    Write-Host "    >> Construyendo $($svc.Nombre)..." -ForegroundColor Cyan
    docker build -f $svc.Dockerfile -t $imageName .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo el build de $($svc.Nombre)" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "    >> Subiendo $($svc.Nombre) a ECR..." -ForegroundColor Cyan
    docker push $imageName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo el push de $($svc.Nombre)" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "    $($svc.Nombre) OK" -ForegroundColor Green
}
Pop-Location

# ================================================================
# 7. PREPARAR RECURSOS AWS PARA EL EC2
# ================================================================
Write-Host ""
Write-Host "==> [7/10] Preparando recursos AWS..." -ForegroundColor Cyan

# VPC ID
$VPC_ID = (aws ec2 describe-vpcs `
    --filters "Name=tag:Proyecto,Values=$PROYECTO" `
    --query "Vpcs[0].VpcId" `
    --output text 2>&1).Trim()
Write-Host "    VPC ID: $VPC_ID" -ForegroundColor Green

# Subnet publica az-a (la primera subnet publica del proyecto)
$SUBNET_PUBLIC_ID = (aws ec2 describe-subnets `
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tipo,Values=publica" `
    --query "Subnets[0].SubnetId" `
    --output text 2>&1).Trim()
Write-Host "    Subnet publica: $SUBNET_PUBLIC_ID" -ForegroundColor Green

# AMI Amazon Linux 2023 (ultima version estable x86_64)
$AMI_ID = (aws ec2 describe-images `
    --owners amazon `
    --filters "Name=name,Values=al2023-ami-*-kernel-*-x86_64" "Name=state,Values=available" `
    --query "sort_by(Images, &CreationDate)[-1].ImageId" `
    --output text 2>&1).Trim()
Write-Host "    AMI: $AMI_ID" -ForegroundColor Green

# Verificar que existe el instance profile LabInstanceProfile (pre-creado por Academy)
$profileExists = aws iam get-instance-profile --instance-profile-name "LabInstanceProfile" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "    ADVERTENCIA: No se encontro LabInstanceProfile. El EC2 puede no tener acceso a ECR." -ForegroundColor Yellow
    $IAM_PROFILE = ""
} else {
    $IAM_PROFILE = "LabInstanceProfile"
    Write-Host "    Instance profile: $IAM_PROFILE" -ForegroundColor Green
}

# Key pair para SSH (por si necesitas depurar)
$keyPairExists = aws ec2 describe-key-pairs --key-names $KEY_NAME 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "    Creando key pair $KEY_NAME..." -ForegroundColor Yellow
    $keyMaterial = (aws ec2 create-key-pair `
        --key-name $KEY_NAME `
        --query "KeyMaterial" `
        --output text 2>&1)
    [System.IO.File]::WriteAllText($KEY_FILE, $keyMaterial, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "    Key guardada en: $KEY_FILE" -ForegroundColor Green
} else {
    Write-Host "    Key pair ya existe: $KEY_NAME" -ForegroundColor Green
}

# ================================================================
# 8. GENERAR SCRIPT DE USER-DATA PARA EL EC2
# ================================================================
Write-Host ""
Write-Host "==> [8/10] Generando user-data para EC2..." -ForegroundColor Cyan

# Nota: En PowerShell @"..."@ expande variables de PS. Los $ de bash se escapan con `$.
$userData = @"
#!/bin/bash
exec > /var/log/sanos-deploy.log 2>&1
echo "=== Inicio deploy Sanos y Salvos $(date) ==="

# ---- Instalar Docker ----
dnf install -y docker
systemctl start docker
systemctl enable docker

# ---- Swap 2GB para t3.micro (1GB RAM + 5 JVMs Spring Boot) ----
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 10 > /proc/sys/vm/swappiness
echo "[OK] Swap 2GB activado"

# ---- Login ECR (usa instance profile LabRole, sin credenciales explicitas) ----
ECR_PASS=`$(aws ecr get-login-password --region $REGION 2>/dev/null)
echo "`$ECR_PASS" | docker login --username AWS --password-stdin $ECR_REGISTRY
echo "[OK] ECR login"

# ---- Red de contenedores ----
docker network create sanos-network

# ---- RabbitMQ ----
docker run -d --name rabbitmq \
  --network sanos-network \
  --restart unless-stopped \
  -e RABBITMQ_DEFAULT_USER=$RABBIT_USER \
  -e RABBITMQ_DEFAULT_PASS=$RABBIT_PASS \
  rabbitmq:3.12-alpine

echo "[OK] RabbitMQ iniciado, esperando 25s..."
sleep 25

# ---- auth-service ----
docker run -d --name auth-service \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8081:8081 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=$RDS_HOST \
  -e DB_USER=$DB_USER \
  -e DB_PASS=$DB_PASS \
  -e REDIS_HOST=$REDIS_HOST \
  -e REDIS_PASS=$REDIS_PASS \
  -e JWT_SECRET=$JWT_SECRET \
  -e MAIL_HOST=localhost \
  -e MAIL_PORT=1025 \
  -e MAIL_USER= \
  -e MAIL_PASS= \
  -e AUTO_VERIFY_EMAIL=true \
  -e FRONTEND_URL=$FRONTEND_URL \
  $ECR_REGISTRY/$PROYECTO/auth-service:latest
echo "[OK] auth-service iniciado"

# ---- ms-mascotas ----
# Nota: MINIO_ENDPOINT apunta a S3. Las fotos requieren credenciales validas.
# Si las credenciales de Academy expiran, redeployar el EC2.
docker run -d --name ms-mascotas \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8082:8082 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=$RDS_HOST \
  -e DB_USER=$DB_USER \
  -e DB_PASS=$DB_PASS \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=$RABBIT_USER \
  -e RABBITMQ_PASS=$RABBIT_PASS \
  -e MINIO_ENDPOINT=https://s3.amazonaws.com \
  -e MINIO_ACCESS_KEY=$accessKey \
  -e MINIO_SECRET_KEY=$secretKey \
  -e JWT_SECRET=$JWT_SECRET \
  $ECR_REGISTRY/$PROYECTO/ms-mascotas:latest
echo "[OK] ms-mascotas iniciado"

# ---- ms-geolocalizacion ----
docker run -d --name ms-geolocalizacion \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8083:8083 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=$RDS_HOST \
  -e DB_USER=$DB_USER \
  -e DB_PASS=$DB_PASS \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=$RABBIT_USER \
  -e RABBITMQ_PASS=$RABBIT_PASS \
  -e JWT_SECRET=$JWT_SECRET \
  $ECR_REGISTRY/$PROYECTO/ms-geolocalizacion:latest
echo "[OK] ms-geolocalizacion iniciado"

# ---- ms-coincidencias ----
docker run -d --name ms-coincidencias \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8084:8084 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=$RDS_HOST \
  -e DB_USER=$DB_USER \
  -e DB_PASS=$DB_PASS \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=$RABBIT_USER \
  -e RABBITMQ_PASS=$RABBIT_PASS \
  -e JWT_SECRET=$JWT_SECRET \
  $ECR_REGISTRY/$PROYECTO/ms-coincidencias:latest
echo "[OK] ms-coincidencias iniciado"

# Dar tiempo a los microservicios para inicializar antes de arrancar el BFF
echo "Esperando 60s para que microservicios inicialicen y creen tablas..."
sleep 60

# ---- bff-service ----
docker run -d --name bff-service \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8080:8080 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e AUTH_HOST=auth-service \
  -e MASCOTAS_HOST=ms-mascotas \
  -e GEO_HOST=ms-geolocalizacion \
  -e COINCIDENCIAS_HOST=ms-coincidencias \
  -e REDIS_HOST=$REDIS_HOST \
  -e REDIS_PASS=$REDIS_PASS \
  -e JWT_SECRET=$JWT_SECRET \
  $ECR_REGISTRY/$PROYECTO/bff-service:latest
echo "[OK] bff-service iniciado"

echo "=== Deploy completo $(date) ==="
"@

Write-Host "    User-data generado ($(($userData.Length / 1024).ToString('F1')) KB)" -ForegroundColor Green

# ================================================================
# 9. GUARDAR USER-DATA Y AMI PARA LANZAMIENTO MANUAL
# ================================================================
Write-Host ""
Write-Host "==> [9/10] Guardando user-data en disco..." -ForegroundColor Cyan

# Nota: ec2:RunInstances esta bloqueado en AWS Academy via CLI.
# El EC2 se debe lanzar desde la consola web de AWS.

$userDataFile = Join-Path $SCRIPT_DIR "user-data.sh"
[System.IO.File]::WriteAllText($userDataFile, $userData, (New-Object System.Text.UTF8Encoding $false))
Write-Host "    Guardado en: $userDataFile" -ForegroundColor Green

# ================================================================
# 10. GUARDAR PARAMETROS PARA register-backend.ps1
# ================================================================
Write-Host ""
Write-Host "==> [10/10] Guardando parametros de configuracion..." -ForegroundColor Cyan

$configData = @{
    TG_BFF_ARN      = $TG_BFF_ARN
    SG_BFF_ID       = $SG_BFF_ID
    SG_MICROS_ID    = $SG_MICROS_ID
    SUBNET_PUBLIC_ID = $SUBNET_PUBLIC_ID
    AMI_ID          = $AMI_ID
    KEY_NAME        = $KEY_NAME
    INSTANCE_NAME   = $INSTANCE_NAME
    ALB_DNS         = $ALB_DNS
    ACCOUNT_ID      = $ACCOUNT_ID
    REGION          = $REGION
    PROYECTO        = $PROYECTO
    ECR_REGISTRY    = $ECR_REGISTRY
    IAM_PROFILE     = $IAM_PROFILE
}
$configFile = Join-Path $SCRIPT_DIR "backend-config.json"
$configData | ConvertTo-Json | Set-Content $configFile -Encoding UTF8
Write-Host "    Guardado en: $configFile" -ForegroundColor Green

# ================================================================
# INSTRUCCIONES MANUALES
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  IMAGENES SUBIDAS A ECR. LANZAR EC2 MANUALMENTE EN CONSOLA." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  ec2:RunInstances esta bloqueado en AWS Academy via CLI." -ForegroundColor Yellow
Write-Host "  Sigue estos pasos en https://console.aws.amazon.com/ec2:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. EC2 > Instances > Launch instances" -ForegroundColor White
Write-Host "  2. Nombre: $INSTANCE_NAME" -ForegroundColor White
Write-Host "  3. AMI:    Amazon Linux 2023 (o busca '$AMI_ID')" -ForegroundColor White
Write-Host "  4. Tipo:   t3.micro" -ForegroundColor White
Write-Host "  5. Key pair: $KEY_NAME (ya existe en tu cuenta)" -ForegroundColor White
Write-Host "  6. Network settings > Edit:" -ForegroundColor White
Write-Host "     - VPC: $($configData.PROYECTO)-vpc" -ForegroundColor Gray
Write-Host "     - Subnet: (publica, az-a, CIDR 10.0.1.0/24)" -ForegroundColor Gray
Write-Host "     - Auto-assign public IP: Enable" -ForegroundColor Gray
Write-Host "     - Security groups: $SG_BFF_ID y $SG_MICROS_ID" -ForegroundColor Gray
Write-Host "  7. Advanced details > IAM instance profile: LabInstanceProfile" -ForegroundColor White
Write-Host "  8. Advanced details > User data: pega el contenido de:" -ForegroundColor White
Write-Host "     $userDataFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Despues de lanzar el EC2, ejecuta:" -ForegroundColor Cyan
Write-Host "    .\register-backend.ps1 -InstanceId i-XXXXXXXXXXXX" -ForegroundColor Yellow
Write-Host ""
Write-Host "  La instancia tarda ~5 min en tener todos los contenedores listos." -ForegroundColor Gray
Write-Host ""

