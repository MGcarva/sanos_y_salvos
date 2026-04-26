# Guía Completa de Despliegue — Sanos y Salvos en AWS Academy

> **Tiempo estimado:** 45–60 minutos la primera vez.  
> **Importante:** AWS Academy borra toda la infraestructura al cerrar la sesión. Esta guía permite recrearla desde cero cada vez.

---

## Convenciones de esta guía

Cada bloque de comandos indica **dónde** ejecutarlo:

| Ícono | Significa |
|---|---|
| 💻 **PowerShell local** | Terminal PowerShell en tu computador |
| 🔵 **CMD / Git Bash local** | Terminal normal en tu computador |
| 🟠 **SSH — dentro del EC2** | Después de conectarte por SSH al servidor |
| 📁 **Directorio requerido** | Carpeta donde debes estar antes de ejecutar |

---

## Índice

1. [Arquitectura general](#1-arquitectura-general)
2. [Prerequisitos](#2-prerequisitos)
3. [Estructura de repositorios](#3-estructura-de-repositorios)
4. [Paso 1 — Obtener credenciales AWS Academy](#4-paso-1--obtener-credenciales-aws-academy)
5. [Paso 2 — Crear infraestructura con Terraform](#5-paso-2--crear-infraestructura-con-terraform)
6. [Paso 3 — Compilar los microservicios](#6-paso-3--compilar-los-microservicios)
7. [Paso 4 — Construir y publicar imágenes Docker en ECR](#7-paso-4--construir-y-publicar-imágenes-docker-en-ecr)
8. [Paso 5 — Inicializar bases de datos en RDS](#8-paso-5--inicializar-bases-de-datos-en-rds)
9. [Paso 6 — Iniciar microservicios en EC2](#9-paso-6--iniciar-microservicios-en-ec2)
10. [Paso 7 — Desplegar el frontend en S3](#10-paso-7--desplegar-el-frontend-en-s3)
11. [Paso 8 — Verificación final](#11-paso-8--verificación-final)
12. [Acceso a las bases de datos](#12-acceso-a-las-bases-de-datos)
13. [Solución de problemas frecuentes](#13-solución-de-problemas-frecuentes)
14. [Destruir la infraestructura](#14-destruir-la-infraestructura)
15. [Variables y credenciales de referencia](#15-variables-y-credenciales-de-referencia)
16. [Checklist rápido](#16-checklist-rápido)

---

## 1. Arquitectura general

```
Internet
  └─> ALB (puerto 80)
        ├── /api/*  ──────────────> EC2:8080 (bff-service)
        └── /*      ──────────────> S3 (frontend React estático)

EC2 t3.medium (Docker)
  ├── bff-service        :8080  → proxy a los 4 microservicios
  ├── auth-service       :8081  → autenticación JWT + Redis
  ├── ms-mascotas        :8082  → reportes de mascotas + S3
  ├── ms-geolocalizacion :8083  → ubicaciones + PostGIS
  ├── ms-coincidencias   :8084  → algoritmo de matching
  └── rabbitmq           :5672  → mensajería entre servicios

RDS PostgreSQL 15 (subred privada)
  ├── auth_db
  ├── mascotas_db
  ├── geolocalizacion_db
  └── coincidencias_db

ElastiCache Redis 7   → sesiones y caché del BFF
S3 bucket             → fotos de mascotas
S3 bucket             → frontend estático
ECR                   → registro de imágenes Docker
```

---

## 2. Prerequisitos

Instala estas herramientas **en tu computador local** antes de empezar:

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| AWS CLI | v2 | https://aws.amazon.com/cli/ |
| Terraform | 1.5+ | https://developer.hashicorp.com/terraform/downloads |
| Docker Desktop | Cualquiera | https://www.docker.com/products/docker-desktop/ |
| Java JDK | 21 o 25 | https://adoptium.net/ |
| Maven | 3.8+ | https://maven.apache.org/download.cgi |
| Node.js + npm | 18+ | https://nodejs.org/ |
| Git | Cualquiera | https://git-scm.com/ |
| OpenSSH | Incluido en Windows 10+ | — |

💻 **PowerShell local** — Verifica que todo esté instalado:

```powershell
aws --version
terraform -v
docker --version
java -version
mvn -version
node --version
npm --version
```

---

## 3. Estructura de repositorios

El proyecto usa **dos repositorios** que deben estar clonados en tu computador:

```
Sanos y salvos/
├── Sanos-y-Salvos/          ← código fuente microservicios + frontend
│   ├── auth-service/
│   ├── ms-mascotas/
│   ├── ms-geolocalizacion/
│   ├── ms-coincidencias/
│   ├── bff-service/
│   └── frontend/
│
└── sanos_y_salvos/          ← infraestructura Terraform  ← ESTÁS AQUÍ
    ├── provider.tf
    ├── variables.tf
    ├── credentials.tf        ← NO está en GitHub (gitignore), crear manualmente
    ├── ec2.tf
    ├── alb.tf
    ├── rds.tf
    ├── elasticache.tf
    ├── ecr.tf
    ├── vpc.tf
    ├── security-groups.tf
    ├── user-data.sh
    ├── update-credentials.ps1
    ├── master-deploy.ps1
    └── smoke-test.ps1
```

💻 **PowerShell local** — Clona los repositorios si aún no los tienes:

```powershell
# Crea la carpeta contenedora
mkdir "C:\proyectos\sanos-y-salvos"
cd "C:\proyectos\sanos-y-salvos"

# Clona ambos repos
git clone https://github.com/tu-org/Sanos-y-Salvos.git
git clone https://github.com/tu-org/sanos_y_salvos.git
```

> **Nota:** El archivo `credentials.tf` contiene las credenciales temporales de AWS Academy y **nunca se sube a GitHub**. Debes crearlo manualmente en cada sesión (el script `update-credentials.ps1` lo hace automáticamente).

---

## 4. Paso 1 — Obtener credenciales AWS Academy

### 4.1 Obtener las credenciales desde el portal

1. Ingresa a **AWS Academy Learner Lab**
2. Haz clic en **Start Lab** y espera que el ícono quede en verde
3. Haz clic en **AWS Details** (panel derecho)
4. Copia las 3 líneas: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`
5. También anota tu **Account ID** (12 dígitos) visible en la consola AWS arriba a la derecha

### 4.2 Actualizar credenciales con el script

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

.\update-credentials.ps1
```

El script te pedirá que pegues las 3 líneas de AWS Details y actualizará `credentials.tf` automáticamente.

### 4.3 Actualizar el Account ID en variables.tf

📁 **Directorio:** `sanos_y_salvos/`

Abre el archivo `variables.tf` y cambia el valor de `aws_account_id`:

```hcl
variable "aws_account_id" {
  description = "ID de la cuenta AWS Academy"
  type        = string
  default     = "111837322528"   # ← reemplaza con tu Account ID real
}
```

### 4.4 Verificar que las credenciales funcionan

💻 **PowerShell local** — Ejecuta desde cualquier directorio:

```powershell
aws sts get-caller-identity
```

Deberías ver tu Account ID en la respuesta. Si da error, repite el paso 4.2.

> **Importante:** Las credenciales de AWS Academy expiran cada ~4 horas. Si algo falla con mensajes de `ExpiredTokenException`, repite los pasos 4.2 y 4.4.

---

## 5. Paso 2 — Crear infraestructura con Terraform

### 5.1 Asegúrate de que Docker Desktop esté corriendo

Ábrelo desde el menú inicio si no está activo. Espera a que el ícono de la ballena quede estático (no animado).

### 5.2 Crear el Key Pair para SSH

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

# Verificar si ya existe
aws ec2 describe-key-pairs --key-names "sanos-y-salvos-key" 2>$null

# Si el comando anterior da error (no existe), crearlo:
$keyResult = aws ec2 create-key-pair --key-name "sanos-y-salvos-key" --output json | ConvertFrom-Json
$keyResult.KeyMaterial | Out-File -FilePath "sanos-y-salvos-key.pem" -Encoding ASCII
Write-Host "Key pair creado y guardado en sanos-y-salvos-key.pem"
```

> Guarda bien el archivo `sanos-y-salvos-key.pem` — lo necesitarás para conectarte al EC2 por SSH.

### 5.3 Limpiar el estado anterior de Terraform

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

# Respaldar y eliminar estado de la sesión anterior
if (Test-Path "terraform.tfstate") {
    Rename-Item "terraform.tfstate" "terraform.tfstate.old-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    Write-Host "Estado anterior respaldado"
}
```

> Esto es necesario porque AWS Academy asigna una cuenta nueva en cada sesión. El estado anterior apunta a recursos que ya no existen.

### 5.4 Inicializar y aplicar Terraform

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

terraform init -upgrade

terraform apply -auto-approve
```

Esto tarda **10–15 minutos**. Crea: VPC, subnets, EC2, ALB, RDS, ElastiCache, ECR, Security Groups.

Al terminar verás los outputs. Guárdalos o consúltalos con:

```powershell
terraform output
```

> **Si hay error `DBInstanceAlreadyExists`:** El RDS quedó de una sesión anterior. Impórtalo:
> ```powershell
> terraform import aws_db_instance.main sanos-y-salvos-postgres
> terraform apply -auto-approve
> ```

---

## 6. Paso 3 — Compilar los microservicios

📁 **Directorio:** `Sanos-y-Salvos/` (raíz del repo de código)

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos"

mvn clean package "-Dmaven.test.skip=true" --no-transfer-progress
```

> **Por qué `-Dmaven.test.skip=true` y no `-DskipTests`?**  
> `-DskipTests` compila los tests pero no los ejecuta. `-Dmaven.test.skip=true` omite también la compilación de tests, que tienen dependencias que pueden fallar en entornos sin servicios corriendo.

Al finalizar deberías ver:

```
[INFO] auth-service .......... SUCCESS [ 10 s]
[INFO] ms-mascotas ........... SUCCESS [  4 s]
[INFO] ms-geolocalizacion .... SUCCESS [  4 s]
[INFO] ms-coincidencias ...... SUCCESS [  3 s]
[INFO] bff-service ........... SUCCESS [  3 s]
[INFO] BUILD SUCCESS
```

### Verificar que los JARs existen

💻 **PowerShell local** — Desde `Sanos-y-Salvos/`:

```powershell
Get-ChildItem -Path . -Recurse -Filter "*.jar" |
  Where-Object { $_.FullName -like "*\target\*" -and $_.Name -notlike "*original*" } |
  Select-Object Name, FullName
```

Deberías ver 5 archivos `.jar`.

---

## 7. Paso 4 — Construir y publicar imágenes Docker en ECR

### 7.1 Configurar Docker para ECR

AWS Academy usa credenciales temporales con session token. El método estándar de `docker login` puede fallar porque Docker Desktop intenta usar un `credsStore` que no soporta session tokens. Este bloque lo soluciona escribiendo la auth directamente:

📁 **Directorio:** `sanos_y_salvos/` (para leer el output de Terraform)

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

$Region      = "us-east-1"
$AccountId   = (aws sts get-caller-identity --query Account --output text)
$EcrRegistry = "$AccountId.dkr.ecr.$Region.amazonaws.com"

# Obtener token y escribir config.json sin credsStore
$ecrToken   = aws ecr get-login-password --region $Region
$authBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("AWS:$ecrToken"))
$configJson = "{`"auths`":{`"$EcrRegistry`":{`"auth`":`"$authBase64`"}}}"

$dockerConfigPath = "$env:USERPROFILE\.docker\config.json"
$sw = New-Object System.IO.StreamWriter($dockerConfigPath, $false, [System.Text.UTF8Encoding]::new($false))
$sw.Write($configJson)
$sw.Close()

Write-Host "Docker configurado para ECR: $EcrRegistry"
```

### 7.2 Construir y publicar las 5 imágenes

📁 **Directorio:** Puedes estar en cualquiera, los paths son absolutos

💻 **PowerShell local:**

```powershell
$AppDir  = "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos"
$Project = "sanos-y-salvos"

$services = @("auth-service", "ms-mascotas", "ms-geolocalizacion", "ms-coincidencias", "bff-service")

foreach ($svc in $services) {
    $imgTag = "$EcrRegistry/$Project/$svc`:latest"
    $svcDir = Join-Path $AppDir $svc

    Write-Host "=== Building $svc ===" -ForegroundColor Cyan
    docker build -t $imgTag -f "$svcDir\Dockerfile.deploy" $svcDir

    Write-Host "=== Pushing $svc ===" -ForegroundColor Cyan
    docker push $imgTag

    Write-Host "[OK] $svc publicado en ECR" -ForegroundColor Green
}
```

> **Tiempo estimado:** ~3–5 minutos en total. Los `Dockerfile.deploy` copian el JAR ya compilado en una imagen Alpine ligera, sin recompilar desde cero.

---

## 8. Paso 5 — Inicializar bases de datos en RDS

El EC2 intenta crear las bases de datos al arrancar, pero a veces RDS no está listo en ese momento. Este paso garantiza que existan antes de levantar los microservicios.

### 8.1 Conectarse al EC2 por SSH

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local** — Obtener la IP del EC2:

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$Ec2Ip = terraform output -raw ec2_public_ip
Write-Host "EC2 IP: $Ec2Ip"
```

🟠 **Abre una nueva ventana de PowerShell y conéctate por SSH:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no ec2-user@<EC2_IP>
```

> Reemplaza `<EC2_IP>` con el valor obtenido arriba. Ahora estás **dentro del servidor EC2**.

### 8.2 Crear las 4 bases de datos

🟠 **SSH — dentro del EC2:**

```bash
export PGPASSWORD="SanosYSalvos2026!"
DB_HOST="<RDS_ENDPOINT>"   # Ver terraform output -> rds_endpoint

for db in auth_db mascotas_db geolocalizacion_db coincidencias_db; do
    psql -h $DB_HOST -U sanosadmin -d postgres -c "CREATE DATABASE $db;" 2>&1
done

# Extensión para búsqueda de texto en coincidencias
psql -h $DB_HOST -U sanosadmin -d coincidencias_db -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo "=== Bases de datos creadas ==="
psql -h $DB_HOST -U sanosadmin -d postgres -c "\l" | grep _db
```

> Las tablas se crean automáticamente cuando Spring Boot arranca con `ddl-auto: update`. Solo necesitas crear las bases de datos vacías.

🟠 **SSH — dentro del EC2** — Sal del SSH cuando termines:

```bash
exit
```

---

## 9. Paso 6 — Iniciar microservicios en EC2

### 9.1 Corregir el script de inicio

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$Ec2Ip = terraform output -raw ec2_public_ip

# Corrige un posible typo en la variable $PROYECTO dentro del script
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "sed -i 's/\$PROJETO/\$PROYECTO/g' /home/ec2-user/start-services.sh && echo 'Script corregido OK'"
```

### 9.2 Lanzar los microservicios

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    'nohup /home/ec2-user/start-services.sh > /tmp/start-output.log 2>&1 & echo "Iniciado PID $!"'
```

El script hace internamente:
1. Login a ECR desde el EC2
2. `docker pull` de las 5 imágenes
3. `docker run` de cada microservicio con sus variables de entorno
4. Espera 90 segundos para que los JVMs arranquen
5. Levanta el BFF al final

**Espera ~3 minutos** y luego verifica:

### 9.3 Verificar contenedores

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

Deberías ver 6 contenedores activos:

```
NAMES                STATUS          PORTS
bff-service          Up 2 minutes    0.0.0.0:8080->8080/tcp
ms-coincidencias     Up 2 minutes    0.0.0.0:8084->8084/tcp
ms-geolocalizacion   Up 2 minutes    0.0.0.0:8083->8083/tcp
ms-mascotas          Up 2 minutes    0.0.0.0:8082->8082/tcp
auth-service         Up 2 minutes    0.0.0.0:8081->8081/tcp
rabbitmq             Up 5 minutes    0.0.0.0:5672->5672/tcp
```

### 9.4 Verificar health de los microservicios

💻 **PowerShell local** — Desde cualquier directorio:

```powershell
# Verificar health desde dentro del EC2
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" @'
for port in 8080 8081 8082 8083 8084; do
    status=$(curl -s --connect-timeout 5 http://localhost:$port/actuator/health \
             | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null \
             || echo "NO_RESP")
    echo "  :$port -> $status"
done
'@
```

Todos deben mostrar `UP`.

### 9.5 Ver logs de un microservicio

Si alguno falla, puedes ver sus logs:

💻 **PowerShell local:**

```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker logs auth-service 2>&1 | tail -40"
```

### 9.6 Reiniciar microservicios

Si necesitas reiniciarlos todos después de un cambio:

💻 **PowerShell local:**

```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker restart auth-service ms-mascotas ms-geolocalizacion ms-coincidencias bff-service"
```

---

## 10. Paso 7 — Desplegar el frontend en S3

### 10.1 Obtener la URL del ALB

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$AlbDns    = terraform output -raw alb_dns
$AccountId = (aws sts get-caller-identity --query Account --output text)
Write-Host "ALB: $AlbDns"
```

### 10.2 Configurar la URL de la API

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos\frontend"

# Crear el archivo de variables de entorno para producción
Set-Content -Path ".env.production" -Value "VITE_API_BASE_URL=http://$AlbDns/api" -Encoding UTF8
Write-Host "API URL configurada: http://$AlbDns/api"
```

### 10.3 Compilar el frontend

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos\frontend"

npm install
npm run build
```

Al terminar se crea la carpeta `dist/` con los archivos estáticos listos para subir a S3.

### 10.4 Crear el bucket S3 y publicar

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos\frontend"

$S3Bucket = "sanos-y-salvos-frontend-$AccountId"

# Crear bucket si no existe
aws s3api head-bucket --bucket $S3Bucket 2>$null
if ($LASTEXITCODE -ne 0) {
    aws s3api create-bucket --bucket $S3Bucket --region us-east-1
    Write-Host "Bucket creado: $S3Bucket"
}

# Configurar acceso público y sitio web estático
aws s3api delete-public-access-block --bucket $S3Bucket
aws s3api put-bucket-policy --bucket $S3Bucket --policy "{
  `"Version`": `"2012-10-17`",
  `"Statement`": [{
    `"Effect`": `"Allow`",
    `"Principal`": `"*`",
    `"Action`": `"s3:GetObject`",
    `"Resource`": `"arn:aws:s3:::$S3Bucket/*`"
  }]
}"
aws s3 website "s3://$S3Bucket" --index-document index.html --error-document index.html

# Subir archivos compilados
aws s3 sync dist/ "s3://$S3Bucket" --delete --cache-control "no-cache" --exclude "assets/*"
aws s3 sync dist/assets/ "s3://$S3Bucket/assets/" --cache-control "max-age=31536000" --delete

Write-Host ""
Write-Host "Frontend disponible en:" -ForegroundColor Green
Write-Host "http://$S3Bucket.s3-website-us-east-1.amazonaws.com" -ForegroundColor Cyan
```

---

## 11. Paso 8 — Verificación final

### 11.1 Smoke test automático

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
.\smoke-test.ps1
```

### 11.2 Verificación manual

📁 **Directorio:** Cualquiera

💻 **PowerShell local:**

```powershell
# 1. Health del BFF via ALB
Invoke-WebRequest -Uri "http://$AlbDns/api/actuator/health" -UseBasicParsing | Select-Object -ExpandProperty Content

# 2. Registro de usuario de prueba
$body = '{"nombre":"Test","email":"test@sanos.cl","password":"Test2026!"}'
Invoke-WebRequest -Uri "http://$AlbDns/api/auth/register" `
    -Method POST -Body $body -ContentType "application/json" -UseBasicParsing |
    Select-Object -ExpandProperty Content

# 3. Frontend
(Invoke-WebRequest -Uri "http://sanos-y-salvos-frontend-$AccountId.s3-website-us-east-1.amazonaws.com" -UseBasicParsing).StatusCode
```

### 11.3 URLs finales de la aplicación

| Recurso | URL |
|---|---|
| **Aplicación completa** | `http://<alb_dns>` |
| **Frontend S3** | `http://sanos-y-salvos-frontend-<account_id>.s3-website-us-east-1.amazonaws.com` |
| **API REST** | `http://<alb_dns>/api` |
| **Health BFF** | `http://<alb_dns>/api/actuator/health` |
| **SSH al EC2** | `ssh -i sanos-y-salvos-key.pem ec2-user@<ec2_ip>` |
| **RabbitMQ Panel** | `http://<ec2_ip>:15672` (user: sanosrabbit) |

---

## 12. Acceso a las bases de datos

El RDS está en una subred privada. Para acceder desde tu computador necesitas un túnel SSH a través del EC2.

### Opción A — Tunnel con pgAdmin (recomendado, sin comandos extra)

En pgAdmin → Register Server:

**Pestaña Connection:**

| Campo | Valor |
|---|---|
| Host | valor de `terraform output rds_endpoint` |
| Port | `5432` |
| Maintenance DB | `postgres` |
| Username | `sanosadmin` |
| Password | `SanosYSalvos2026!` |

**Pestaña SSH Tunnel:**

| Campo | Valor |
|---|---|
| Use SSH tunneling | ✅ ON |
| Tunnel host | IP del EC2 (`terraform output ec2_public_ip`) |
| Tunnel port | `22` |
| Username | `ec2-user` |
| Authentication | Identity file |
| Identity file | Ruta completa al archivo `sanos-y-salvos-key.pem` |

### Opción B — Tunnel manual por PowerShell

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local** — Abre una ventana dedicada y déjala corriendo:

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$Ec2Ip  = terraform output -raw ec2_public_ip
$DbHost = terraform output -raw rds_endpoint

# Deja esta ventana abierta. El puerto 5433 local apunta al RDS en AWS.
ssh -i "sanos-y-salvos-key.pem" -L "5433:${DbHost}:5432" ec2-user@$Ec2Ip -N
```

Luego conecta cualquier cliente SQL a `localhost:5433` con usuario `sanosadmin`.

> Usa puerto `5433` (no `5432`) para evitar conflicto con PostgreSQL local si lo tienes instalado.

### Consultas SQL útiles

Una vez conectado con pgAdmin o psql:

```sql
-- Conectar a una base de datos específica
\c mascotas_db

-- Ver todas las tablas
\dt

-- Últimos reportes registrados
SELECT id, nombre, tipo, especie, estado, created_at
FROM reportes
ORDER BY created_at DESC
LIMIT 20;

-- Usuarios registrados
\c auth_db
SELECT id, nombre, email, rol, email_verified, created_at
FROM users
ORDER BY created_at DESC;

-- Coincidencias encontradas
\c coincidencias_db
SELECT id, reporte_perdido_id, reporte_encontrado_id, score, estado
FROM coincidencias
ORDER BY created_at DESC;
```

---

## 13. Solución de problemas frecuentes

### ❌ ExpiredTokenException — credenciales inválidas

**Síntoma:** Cualquier comando `aws` falla con `ExpiredTokenException`.

**Causa:** Las credenciales de AWS Academy duran ~4 horas.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
.\update-credentials.ps1    # pegar las nuevas credenciales del portal
aws sts get-caller-identity  # verificar que funcionen
```

---

### ❌ database "auth_db" does not exist

**Síntoma:** Los logs de los microservicios muestran `FATAL: database "X" does not exist`.

**Causa:** RDS no estaba listo cuando el EC2 intentó crear las BDs al arrancar.

💻 **PowerShell local** — Crea las BDs y reinicia los contenedores:

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$Ec2Ip  = terraform output -raw ec2_public_ip
$DbHost = terraform output -raw rds_endpoint

ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" "
export PGPASSWORD='SanosYSalvos2026!'
for db in auth_db mascotas_db geolocalizacion_db coincidencias_db; do
    psql -h $DbHost -U sanosadmin -d postgres -c \"CREATE DATABASE \$db;\" 2>&1
done
echo 'Listo'
"

# Reiniciar microservicios para que se conecten a las BDs recién creadas
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker restart auth-service ms-mascotas ms-geolocalizacion ms-coincidencias"
```

---

### ❌ Docker ECR login 400 Bad Request

**Síntoma:** El push de imágenes falla con `400 Bad Request` o `no basic auth credentials`.

**Causa:** Docker Desktop intenta usar su `credsStore` que no soporta session tokens de AWS Academy.

**Solución:** Repite el bloque completo del [Paso 7.1](#71-configurar-docker-para-ecr).

---

### ❌ Maven BUILD FAILURE — cannot find symbol (Lombok)

**Síntoma:** La compilación falla con errores como `cannot find symbol: method isActive()` o `variable log`.

**Causa:** Lombok no es compatible con la versión de Java instalada (si tienes Java 22+).

📁 **Directorio:** `Sanos-y-Salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos"

# El pom.xml ya usa Lombok 1.18.42 (soporta Java 21-25)
# Fuerza la descarga de dependencias actualizadas:
mvn clean package "-Dmaven.test.skip=true" -U --no-transfer-progress
```

---

### ❌ Microservicio en estado DOWN

**Síntoma:** Health check devuelve `{"status":"DOWN"}`.

💻 **PowerShell local** — Ver el log del servicio con problema:

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$Ec2Ip = terraform output -raw ec2_public_ip

ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker logs auth-service 2>&1 | tail -30"
```

Causas frecuentes:

| Componente DOWN | Solución |
|---|---|
| `db` | La base de datos no existe → ver problema anterior |
| `mail` | Normal, no hay servidor de email → no afecta el funcionamiento |
| `redis` | Verificar que ElastiCache existe: `terraform output` |
| `rabbit` | Verificar que el contenedor rabbitmq esté corriendo: `docker ps` |

---

### ❌ Estado de Terraform de otra cuenta

**Síntoma:** Terraform intenta modificar recursos de la sesión anterior que ya no existen.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

Rename-Item "terraform.tfstate" "terraform.tfstate.old"
terraform apply -auto-approve
```

---

### ❌ El frontend muestra error de API / CORS

**Síntoma:** La app carga pero al hacer login o registrarse da error de red.

**Causa:** La URL de la API en `.env.production` apunta al ALB de la sesión anterior.

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$AlbDns = terraform output -raw alb_dns

cd "..\Sanos-y-Salvos\frontend"
Set-Content -Path ".env.production" -Value "VITE_API_BASE_URL=http://$AlbDns/api" -Encoding UTF8
npm run build

# Volver a sincronizar con S3
$AccountId = (aws sts get-caller-identity --query Account --output text)
aws s3 sync dist/ "s3://sanos-y-salvos-frontend-$AccountId" --delete --cache-control "no-cache" --exclude "assets/*"
aws s3 sync dist/assets/ "s3://sanos-y-salvos-frontend-$AccountId/assets/" --cache-control "max-age=31536000" --delete
```

---

## 14. Destruir la infraestructura

Cuando termines la presentación o quieras liberar recursos:

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

# Vaciar el bucket S3 primero (S3 no se puede destruir si tiene archivos)
$AccountId = (aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://sanos-y-salvos-frontend-$AccountId" --recursive

# Destruir toda la infraestructura (~5-10 minutos)
terraform destroy -auto-approve
```

---

## 15. Variables y credenciales de referencia

### Base de datos RDS

| Variable | Valor |
|---|---|
| Usuario | `sanosadmin` |
| Contraseña | `SanosYSalvos2026!` |
| Puerto | `5432` |
| Motor | PostgreSQL 15 |
| Bases de datos | `auth_db`, `mascotas_db`, `geolocalizacion_db`, `coincidencias_db` |

### Redis (ElastiCache)

| Variable | Valor |
|---|---|
| Contraseña | `SanosRedis2026!` |
| Puerto | `6379` |

### RabbitMQ

| Variable | Valor |
|---|---|
| Usuario | `sanosrabbit` |
| Contraseña | `SanosRabbit2026!` |
| Puerto AMQP | `5672` |
| Panel web | `http://<ec2_ip>:15672` |

### Puertos de los microservicios en EC2

| Servicio | Puerto |
|---|---|
| bff-service | `8080` |
| auth-service | `8081` |
| ms-mascotas | `8082` |
| ms-geolocalizacion | `8083` |
| ms-coincidencias | `8084` |

### Región AWS

```
us-east-1
```

---

## 16. Checklist rápido

Usa esta lista cada vez que debas re-desplegar desde cero:

```
PREPARACIÓN
[ ] Abrir AWS Academy → Start Lab → esperar luz verde
[ ] Copiar credenciales de AWS Details (3 líneas)
[ ] PowerShell → cd sanos_y_salvos\
[ ] .\update-credentials.ps1 → pegar credenciales
[ ] Editar variables.tf → actualizar aws_account_id
[ ] aws sts get-caller-identity → verificar cuenta

INFRAESTRUCTURA
[ ] aws ec2 create-key-pair... → guardar .pem
[ ] Renombrar terraform.tfstate anterior si existe
[ ] terraform init -upgrade
[ ] terraform apply -auto-approve  (~10-15 min)
[ ] terraform output → anotar ec2_public_ip y alb_dns

COMPILAR Y DOCKERIZAR
[ ] Docker Desktop abierto y corriendo
[ ] cd Sanos-y-Salvos\
[ ] mvn clean package "-Dmaven.test.skip=true"
[ ] Ejecutar bloque PowerShell de configuración ECR (Paso 7.1)
[ ] Build y push de las 5 imágenes Docker

BACKEND
[ ] SSH al EC2 → crear 4 bases de datos en RDS
[ ] Ejecutar start-services.sh en el EC2
[ ] Esperar ~3 minutos
[ ] Verificar: docker ps → 6 contenedores UP
[ ] Verificar: health de los 5 servicios → UP

FRONTEND
[ ] Actualizar .env.production con nuevo ALB DNS
[ ] cd Sanos-y-Salvos\frontend\
[ ] npm run build
[ ] Crear bucket S3 y sincronizar dist/

VERIFICACIÓN
[ ] .\smoke-test.ps1 → todos los checks pasan
[ ] Abrir frontend en el navegador → funciona
[ ] Registrar usuario de prueba → responde OK
```

---

*Guía generada para el proyecto Sanos y Salvos — AWS Academy deployment.*  
*Repositorio de código: `Sanos-y-Salvos` | Repositorio de infraestructura: `sanos_y_salvos`*
