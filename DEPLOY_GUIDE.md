# 🚀 Guía Completa de Despliegue — Sanos y Salvos en AWS Academy

> **Tiempo estimado:** 45–60 minutos la primera vez.
> **Importante:** AWS Academy borra toda la infraestructura al cerrar la sesión. Esta guía permite recrearla desde cero en cada sesión.

---

> ## ⚠️ ADAPTA LAS RUTAS ANTES DE EJECUTAR CUALQUIER COMANDO
>
> Las rutas de los repositorios **son distintas en cada computador**. Ejecuta este bloque una sola vez al abrir PowerShell. Todos los comandos `cd` de esta guía usan estas variables:
>
> ```powershell
> # ─────────────────────────────────────────────────────────────────
> # PERSONALIZA según donde tienes clonados los repositorios
> # ─────────────────────────────────────────────────────────────────
> $INFRA_DIR = "C:\ruta\a\sanos_y_salvos"    # ← infraestructura Terraform
> $CODE_DIR  = "C:\ruta\a\Sanos-y-Salvos"    # ← código fuente (microservicios + frontend)
>
> # Ejemplos:
> # $INFRA_DIR = "C:\Users\TuUsuario\Desktop\sanos_y_salvos"
> # $INFRA_DIR = "C:\Users\TuUsuario\Documents\GitHub\sanos_y_salvos"
> # ─────────────────────────────────────────────────────────────────
> ```
>
> ⚡ **Tip:** Copia este bloque a un archivo de texto y pégalo siempre al abrir una sesión nueva.

---

## 📖 Convenciones

| Ícono | Significa |
|---|---|
| 💻 **PowerShell local** | Terminal PowerShell en tu computador |
| 🟠 **SSH — dentro del EC2** | Después de conectarte por SSH al servidor |
| 📁 **Directorio requerido** | Carpeta donde debes estar |
| 🧠 **Concepto** | Explicación educativa de qué hace ese paso |

---

## 📋 Índice

1. [Arquitectura — qué se va a crear](#1-arquitectura--qué-se-va-a-crear)
2. [Prerequisitos](#2-prerequisitos)
3. [PASO 1 — Credenciales AWS Academy](#3-paso-1--credenciales-aws-academy)
4. [PASO 2 — Key Pair SSH](#4-paso-2--key-pair-ssh)
5. [PASO 3 — Infraestructura con Terraform](#5-paso-3--infraestructura-con-terraform)
6. [PASO 4 — Compilar los microservicios](#6-paso-4--compilar-los-microservicios)
7. [PASO 5 — Imágenes Docker en ECR](#7-paso-5--imágenes-docker-en-ecr)
8. [PASO 6 — Bases de datos en RDS](#8-paso-6--bases-de-datos-en-rds)
9. [PASO 7 — Iniciar microservicios en EC2](#9-paso-7--iniciar-microservicios-en-ec2)
10. [PASO 8 — Frontend en S3](#10-paso-8--frontend-en-s3)
11. [PASO 9 — Verificación final](#11-paso-9--verificación-final)
12. [Acceso a las bases de datos](#12-acceso-a-las-bases-de-datos)
13. [Destruir toda la infraestructura](#13-destruir-toda-la-infraestructura)
14. [Solución de problemas](#14-solución-de-problemas)
15. [Credenciales y puertos de referencia](#15-credenciales-y-puertos-de-referencia)
16. [Checklist rápido](#16-checklist-rápido)

---

## 1. Arquitectura — qué se va a crear

```
Internet
  └─> ALB (puerto 80)           ← Application Load Balancer: recibe todo el tráfico
        ├── /api/*  ──────────> EC2:8080 (bff-service)
        └── /*      ──────────> S3 (frontend React estático)

EC2 t3.medium (Docker)          ← Un servidor con todos los servicios en contenedores
  ├── bff-service        :8080  ← Backend For Frontend: proxy hacia los microservicios
  ├── auth-service       :8081  ← Autenticación, JWT, usuarios
  ├── ms-mascotas        :8082  ← Reportes de mascotas perdidas/encontradas
  ├── ms-geolocalizacion :8083  ← Ubicaciones y georeferenciación
  ├── ms-coincidencias   :8084  ← Algoritmo de matching entre reportes
  └── rabbitmq           :5672  ← Cola de mensajes entre microservicios

RDS PostgreSQL 15               ← Base de datos relacional en subred privada
  ├── auth_db
  ├── mascotas_db
  ├── geolocalizacion_db
  └── coincidencias_db

ElastiCache Redis 7             ← Caché en memoria para sesiones y respuestas frecuentes
S3 bucket                       ← Almacenamiento de fotos de mascotas
S3 bucket                       ← Frontend React compilado (archivos estáticos)
ECR                             ← Registro privado de imágenes Docker (como Docker Hub pero de AWS)
```

🧠 **¿Por qué esta arquitectura?**
AWS Academy no permite usar ECS (el orquestador de contenedores de AWS). Por eso usamos una sola instancia EC2 con Docker, que es más simple y funciona igual para una demo. El ALB distribuye el tráfico entre el backend (API) y el frontend (S3).

---

## 2. Prerequisitos

Instala estas herramientas en tu computador antes de comenzar:

| Herramienta | Para qué se usa | Descarga |
|---|---|---|
| AWS CLI v2 | Comandos hacia AWS desde terminal | https://aws.amazon.com/cli/ |
| Terraform 1.5+ | Crear infraestructura como código | https://developer.hashicorp.com/terraform/downloads |
| Docker Desktop | Construir y subir imágenes de los microservicios | https://www.docker.com/products/docker-desktop/ |
| Java JDK 21+ | Compilar los microservicios Spring Boot | https://adoptium.net/ |
| Maven 3.8+ | Gestor de dependencias y build de Java | https://maven.apache.org/download.cgi |
| Node.js 18+ | Compilar el frontend React (Vite) | https://nodejs.org/ |
| OpenSSH | Conectarse al servidor EC2 por SSH | Incluido en Windows 10+ |

💻 **PowerShell local** — Verifica versiones:
```powershell
aws --version
terraform -v
docker --version
java -version
mvn -version
node --version
```

---

## 3. PASO 1 — Credenciales AWS Academy

🧠 **¿Qué son las credenciales?**
AWS usa un sistema de llaves para autenticar quién hace qué. AWS Academy te da credenciales temporales (duran ~4 horas) compuestas por:
- `aws_access_key_id`: como un "usuario"
- `aws_secret_access_key`: como una "contraseña"
- `aws_session_token`: token extra por ser sesión temporal

Sin estas 3 llaves, ningún comando `aws` ni Terraform pueden crear recursos.

### 3.1 Obtener las credenciales

1. Abre **AWS Academy Learner Lab**
2. Clic en **▶ Start Lab** — espera que el círculo quede **verde**
3. Clic en **AWS Details** (panel derecho)
4. Copia las 3 líneas que aparecen
5. Anota el **Account ID** (12 dígitos) — lo verás en la consola AWS arriba a la derecha

### 3.2 Actualizar las credenciales

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR

.\update-credentials.ps1
```

Pega las 3 líneas cuando te las pida y presiona Enter dos veces.

### 3.3 Verificar que funcionan

💻 **PowerShell local:**
```powershell
aws sts get-caller-identity
```

✅ Respuesta esperada:
```json
{
    "Account": "895112511964",
    "Arn": "arn:aws:sts::895112511964:assumed-role/voclabs/user..."
}
```

> ⚠️ **Si ves `ExpiredTokenException` en cualquier paso:** las credenciales caducaron. Repite este paso 3.

---

## 4. PASO 2 — Key Pair SSH

🧠 **¿Para qué sirve un Key Pair?**
Un Key Pair es un par de llaves criptográficas. AWS guarda la llave pública en el servidor EC2. Tú guardas la llave privada (`.pem`) en tu computador. Cuando haces SSH, las llaves se verifican mutuamente sin necesitar contraseña. Es más seguro que una contraseña.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR

# Verifica si ya existe de una sesión anterior
aws ec2 describe-key-pairs --key-names "sanos-y-salvos-key" --region us-east-1 2>$null

# Si NO existe (el comando anterior da error), créalo:
$keyResult = aws ec2 create-key-pair --key-name "sanos-y-salvos-key" --region us-east-1 --output json | ConvertFrom-Json
$keyResult.KeyMaterial | Out-File -FilePath "sanos-y-salvos-key.pem" -Encoding ASCII
Write-Host "Key pair creado y guardado en sanos-y-salvos-key.pem"
```

> ⚠️ Guarda el archivo `sanos-y-salvos-key.pem` — sin él no puedes conectarte al servidor.

---

## 5. PASO 3 — Infraestructura con Terraform

🧠 **¿Qué es Terraform?**
Terraform es una herramienta de "Infraestructura como Código" (IaC). En lugar de crear servidores manualmente en la consola de AWS (haciendo clic), describes todo en archivos `.tf` y Terraform lo crea automáticamente. Ventajas:
- Reproducible: el mismo código crea la misma infraestructura siempre
- Versionable: los archivos van en Git
- Destruible: un solo comando elimina todo

**¿Qué crean los archivos `.tf` de este proyecto?**

| Archivo | Qué crea |
|---|---|
| `vpc.tf` | Red virtual privada, subnets públicas y privadas, tablas de rutas |
| `security-groups.tf` | Firewalls que controlan qué tráfico entra/sale de cada recurso |
| `ec2.tf` | Servidor virtual con Docker preinstalado |
| `alb.tf` | Load Balancer que distribuye el tráfico |
| `rds.tf` | Base de datos PostgreSQL |
| `elasticache.tf` | Redis en memoria |
| `ecr.tf` | Registro privado de imágenes Docker |
| `secrets.tf` | Almacén seguro de contraseñas |

### 5.1 Limpiar estado anterior

🧠 **¿Qué es el estado de Terraform?**
Terraform guarda en `terraform.tfstate` un mapa de "qué recursos creó". Si la cuenta de AWS cambia (como en Academy), ese mapa apunta a recursos que ya no existen y causa errores. Por eso lo limpiamos al inicio de cada sesión.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR

if (Test-Path "terraform.tfstate") {
    Rename-Item "terraform.tfstate" "terraform.tfstate.old-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    Write-Host "Estado anterior respaldado"
}
```

### 5.2 Inicializar Terraform

🧠 **¿Qué hace `terraform init`?**
Descarga los "proveedores" (plugins) necesarios. En este caso descarga el proveedor de AWS, que contiene las instrucciones para crear cada tipo de recurso AWS.

💻 **PowerShell local:**
```powershell
terraform init -upgrade
```

### 5.3 Aplicar la infraestructura

🧠 **¿Qué hace `terraform apply`?**
Lee todos los archivos `.tf`, calcula qué recursos necesita crear, y los crea en AWS en el orden correcto (primero la VPC, luego las subnets dentro de ella, etc.). El flag `-auto-approve` evita la confirmación manual.

💻 **PowerShell local:**
```powershell
terraform apply -auto-approve
```

⏱️ **Tiempo estimado: 10–15 minutos** (RDS tarda más)

Al terminar, guarda los valores de output:
```powershell
terraform output
```

Los más importantes:
- `ec2_public_ip` → IP del servidor
- `alb_dns` → URL del Load Balancer
- `rds_endpoint` → Dirección de la base de datos

---

## 6. PASO 4 — Compilar los microservicios

🧠 **¿Por qué compilamos localmente?**
Los microservicios están escritos en Java con Spring Boot. Maven descarga las dependencias y compila el código fuente en archivos `.jar` (ejecutables Java). Compilamos localmente para no hacerlo dentro de Docker (sería más lento y complejo).

El flag `-Dmaven.test.skip=true` omite la compilación de tests que tienen dependencias externas (bases de datos, etc.) que no están disponibles en local.

📁 **Directorio:** `Sanos-y-Salvos/` (repo de código)

💻 **PowerShell local:**
```powershell
cd $CODE_DIR

mvn clean package "-Dmaven.test.skip=true" --no-transfer-progress
```

✅ Al terminar deberías ver:
```
[INFO] auth-service ........... SUCCESS
[INFO] ms-mascotas ............ SUCCESS
[INFO] ms-geolocalizacion ..... SUCCESS
[INFO] ms-coincidencias ....... SUCCESS
[INFO] bff-service ............ SUCCESS
[INFO] BUILD SUCCESS
```

Verifica que los JARs existen:
```powershell
Get-ChildItem -Recurse -Filter "*.jar" | Where-Object { $_.FullName -like "*\target\*" -and $_.Name -notlike "*original*" }
```

---

## 7. PASO 5 — Imágenes Docker en ECR

🧠 **¿Qué es Docker y ECR?**
Docker empaqueta cada microservicio con todo lo que necesita (Java, el JAR, configuración) en una "imagen" portable. ECR (Elastic Container Registry) es el registro privado de AWS donde guardamos esas imágenes, como un Docker Hub privado.

**¿Qué hace `Dockerfile.deploy`?**
```dockerfile
FROM eclipse-temurin:21-jre-alpine   # Imagen base con Java 21 (Alpine = muy liviana, ~50MB)
WORKDIR /app
COPY target/auth-service-1.0.0.jar app.jar  # Copia el JAR ya compilado
EXPOSE 8081
ENTRYPOINT ["java","-jar","app.jar"]  # Al iniciar el contenedor, ejecuta el JAR
```

### 7.1 Configurar Docker para ECR

🧠 **¿Por qué este paso especial?**
Docker Desktop guarda credenciales en un "credsStore" del sistema. Pero las credenciales temporales de AWS Academy tienen un `session_token` extra que ese store no soporta. Por eso escribimos la autenticación directamente en el archivo de configuración de Docker.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR

$Region      = "us-east-1"
$AccountId   = (aws sts get-caller-identity --query Account --output text)
$EcrRegistry = "$AccountId.dkr.ecr.$Region.amazonaws.com"

$ecrToken   = aws ecr get-login-password --region $Region
$authBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("AWS:$ecrToken"))
$configJson = "{`"auths`":{`"$EcrRegistry`":{`"auth`":`"$authBase64`"}}}"

$sw = New-Object System.IO.StreamWriter("$env:USERPROFILE\.docker\config.json", $false, [System.Text.UTF8Encoding]::new($false))
$sw.Write($configJson)
$sw.Close()

Write-Host "Docker autenticado en ECR: $EcrRegistry" -ForegroundColor Green
```

### 7.2 Construir y subir las 5 imágenes

💻 **PowerShell local:**
```powershell
$AppDir  = $CODE_DIR   # ← ya definida al inicio de la guía
$Project = "sanos-y-salvos"

foreach ($svc in @("auth-service","ms-mascotas","ms-geolocalizacion","ms-coincidencias","bff-service")) {
    $imgTag = "$EcrRegistry/$Project/$svc`:latest"
    $svcDir = Join-Path $AppDir $svc
    Write-Host "=== $svc ===" -ForegroundColor Cyan
    docker build -t $imgTag -f "$svcDir\Dockerfile.deploy" $svcDir
    docker push $imgTag
    Write-Host "[OK] $svc en ECR" -ForegroundColor Green
}
```

⏱️ **Tiempo estimado: 5–8 minutos**

---

## 8. PASO 6 — Bases de datos en RDS

🧠 **¿Por qué crear las BDs manualmente?**
Terraform crea el servidor RDS (el motor PostgreSQL), pero no crea las bases de datos individuales dentro de él. Los microservicios Spring Boot crean las **tablas** automáticamente al arrancar (con `ddl-auto: update`), pero primero necesitan que la **base de datos** exista.

Si RDS no estaba listo cuando el EC2 arrancó (race condition), este paso garantiza que las BDs existen.

### 8.1 Conectarse al EC2

🧠 **¿Por qué SSH?**
El RDS está en una subred **privada** (no tiene acceso desde Internet). Solo el EC2, que está en la misma VPC, puede conectarse. Por eso primero nos conectamos al EC2 y desde ahí accedemos al RDS.

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local** — obtén la IP del EC2:
```powershell
cd $INFRA_DIR
$Ec2Ip = terraform output -raw ec2_public_ip
$DbHost = terraform output -raw rds_host
Write-Host "EC2: $Ec2Ip"
Write-Host "RDS: $DbHost"
```

💻 **PowerShell local** — conecta por SSH:
```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no ec2-user@$Ec2Ip
```

### 8.2 Crear las 4 bases de datos

🟠 **SSH — dentro del EC2:**
```bash
export PGPASSWORD="SanosYSalvos2026!"
DB_HOST="<valor de rds_host>"

for db in auth_db mascotas_db geolocalizacion_db coincidencias_db; do
    psql -h $DB_HOST -U sanosadmin -d postgres -c "CREATE DATABASE $db;" 2>&1
    echo "BD creada: $db"
done

# Extensión de búsqueda de texto para el algoritmo de coincidencias
psql -h $DB_HOST -U sanosadmin -d coincidencias_db -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Verificar que se crearon
psql -h $DB_HOST -U sanosadmin -d postgres -c "\l" | grep _db
```

🟠 **SSH — salir del EC2:**
```bash
exit
```

---

## 9. PASO 7 — Iniciar microservicios en EC2

🧠 **¿Qué hace `start-services.sh`?**
El script fue copiado al EC2 por Terraform durante el arranque (user-data). Hace lo siguiente:
1. Login a ECR para poder descargar las imágenes privadas
2. `docker pull` de cada imagen desde ECR
3. `docker run` de cada contenedor con sus variables de entorno (DB_HOST, REDIS_HOST, etc.)
4. Espera 90 segundos para que los JVMs arranquen
5. Levanta el BFF al final (que depende de que los demás estén listos)

### 9.1 Corregir script y lanzar servicios

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR
$Ec2Ip = terraform output -raw ec2_public_ip

# Lanzar el script en background (nohup = sigue corriendo aunque cerremos el SSH)
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    'nohup /home/ec2-user/start-services.sh > /tmp/start-output.log 2>&1 & echo "PID: $!"'
```

Espera **3 minutos** y verifica:

```powershell
# Ver contenedores corriendo
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

✅ Deberías ver 6 contenedores con estado `Up`:
```
NAMES                STATUS         PORTS
bff-service          Up 2 minutes   0.0.0.0:8080->8080/tcp
ms-coincidencias     Up 2 minutes   0.0.0.0:8084->8084/tcp
ms-geolocalizacion   Up 2 minutes   0.0.0.0:8083->8083/tcp
ms-mascotas          Up 2 minutes   0.0.0.0:8082->8082/tcp
auth-service         Up 2 minutes   0.0.0.0:8081->8081/tcp
rabbitmq             Up 5 minutes   0.0.0.0:5672->5672/tcp
```

### 9.2 Ver logs si algo falla

```powershell
# Reemplaza "auth-service" por el nombre del servicio con problemas
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker logs auth-service 2>&1 | tail -40"
```

### 9.3 Reiniciar un servicio

```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker restart auth-service"
```

---

## 10. PASO 8 — Frontend en S3

🧠 **¿Por qué S3 para el frontend?**
El frontend es una aplicación React que se compila en archivos estáticos (HTML, CSS, JS). S3 puede servir archivos estáticos como sitio web con muy alta disponibilidad y sin administrar servidores. Es más barato y simple que un servidor dedicado para el frontend.

🧠 **¿Qué es `VITE_API_BASE_URL`?**
Vite (el compilador de React) permite inyectar variables de entorno en el código en tiempo de compilación. La variable `VITE_API_BASE_URL` le dice al frontend dónde está el backend (la URL del ALB). Como el ALB cambia en cada sesión de Academy, hay que actualizarla antes de compilar.

### 10.1 Actualizar la URL del API

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR
$AlbDns    = terraform output -raw alb_dns
$AccountId = (aws sts get-caller-identity --query Account --output text)

cd "..\Sanos-y-Salvos\frontend"
Set-Content -Path ".env.production" -Value "VITE_API_BASE_URL=http://$AlbDns/api" -Encoding UTF8
Write-Host "API URL: http://$AlbDns/api"
```

### 10.2 Compilar y desplegar

💻 **PowerShell local:**
```powershell
cd "$CODE_DIR\frontend"

npm install
npm run build

# Crear bucket S3
$S3Bucket = "sanos-y-salvos-frontend-$AccountId"
aws s3api head-bucket --bucket $S3Bucket 2>$null
if ($LASTEXITCODE -ne 0) {
    aws s3api create-bucket --bucket $S3Bucket --region us-east-1
}

# Configurar acceso público (necesario para sitio web estático)
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

# Subir archivos (assets con caché largo, resto sin caché)
aws s3 sync dist/ "s3://$S3Bucket" --delete --cache-control "no-cache" --exclude "assets/*"
aws s3 sync dist/assets/ "s3://$S3Bucket/assets/" --cache-control "max-age=31536000" --delete

Write-Host "Frontend disponible en: http://$S3Bucket.s3-website-us-east-1.amazonaws.com"
```

---

## 11. PASO 9 — Verificación final

### 11.1 Smoke test automático

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR
.\smoke-test.ps1
```

### 11.2 Verificación manual

💻 **PowerShell local:**
```powershell
$AlbDns    = terraform output -raw alb_dns
$AccountId = (aws sts get-caller-identity --query Account --output text)

# 1. Health del BFF
Invoke-WebRequest -Uri "http://$AlbDns/api/actuator/health" -UseBasicParsing | Select-Object -ExpandProperty Content

# 2. Registrar usuario de prueba
$body = '{"nombre":"Test","email":"test@sanos.cl","password":"Test2026!"}'
Invoke-WebRequest -Uri "http://$AlbDns/api/auth/register" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing | Select-Object -ExpandProperty Content

# 3. Verificar frontend
(Invoke-WebRequest -Uri "http://sanos-y-salvos-frontend-$AccountId.s3-website-us-east-1.amazonaws.com" -UseBasicParsing).StatusCode
```

### 11.3 URLs de la aplicación

| Recurso | URL |
|---|---|
| **API Health** | `http://<alb_dns>/api/actuator/health` |
| **API REST** | `http://<alb_dns>/api` |
| **Frontend** | `http://sanos-y-salvos-frontend-<account_id>.s3-website-us-east-1.amazonaws.com` |
| **RabbitMQ Panel** | `http://<ec2_ip>:15672` (user: `sanosrabbit`) |
| **SSH al EC2** | `ssh -i sanos-y-salvos-key.pem ec2-user@<ec2_ip>` |

---

## 12. Acceso a las bases de datos

🧠 **¿Por qué necesito un túnel SSH?**
El RDS está en una subred **privada** — no tiene IP pública y no acepta conexiones desde Internet. Para acceder desde tu computador necesitas "saltar" a través del EC2 que sí es accesible públicamente. El túnel SSH redirige un puerto local de tu computador al RDS a través del EC2.

```
Tu PC (localhost:5433) ──SSH──> EC2 ──VPC──> RDS (puerto 5432)
```

### Opción A — pgAdmin con SSH Tunnel integrado (recomendado)

En pgAdmin → Register Server:

**Pestaña Connection:**
| Campo | Valor |
|---|---|
| Host | `<valor de terraform output rds_host>` |
| Port | `5432` |
| Username | `sanosadmin` |
| Password | `SanosYSalvos2026!` |

**Pestaña SSH Tunnel:**
| Campo | Valor |
|---|---|
| Use SSH tunneling | ✅ Activado |
| Tunnel host | `<valor de terraform output ec2_public_ip>` |
| Tunnel port | `22` |
| Username | `ec2-user` |
| Authentication | Identity file |
| Identity file | ruta al archivo `sanos-y-salvos-key.pem` |

### Opción B — Túnel manual por PowerShell

💻 **PowerShell local** — abre una ventana dedicada y déjala corriendo:
```powershell
cd $INFRA_DIR
$Ec2Ip  = terraform output -raw ec2_public_ip
$DbHost = terraform output -raw rds_host

# Puerto 5433 local para no chocar con PostgreSQL local (5432)
ssh -i "sanos-y-salvos-key.pem" -L "5433:${DbHost}:5432" ec2-user@$Ec2Ip -N
```

Luego conecta cualquier cliente a `localhost:5433` con usuario `sanosadmin`.

### Consultas SQL útiles

```sql
-- Ver mascotas reportadas
\c mascotas_db
SELECT id, nombre, tipo, especie, estado, created_at FROM reportes ORDER BY created_at DESC LIMIT 20;

-- Ver usuarios registrados
\c auth_db
SELECT id, nombre, email, created_at FROM users ORDER BY created_at DESC;

-- Ver coincidencias encontradas
\c coincidencias_db
SELECT id, reporte_perdido_id, reporte_encontrado_id, score, estado FROM coincidencias ORDER BY created_at DESC;
```

---

## 13. Destruir toda la infraestructura

🧠 **¿Cuándo destruir?**
- Al terminar la presentación para liberar recursos y evitar costos
- Antes de empezar una nueva sesión de Academy (para partir limpio)
- AWS Academy lo hace automáticamente al cerrar el lab, pero es buena práctica hacerlo manualmente

### 13.1 Destruir con Terraform (método correcto)

> ⚠️ **Flag importante: `-refresh=false`**
> Sin este flag, Terraform intenta leer el estado actual de AWS antes de destruir (para verificar qué existe). En AWS Academy esto falla porque `ec2:DescribeImages` e `iam:GetRole` están bloqueados por la política `voc-cancel-cred`. El flag `-refresh=false` le dice a Terraform "confía en lo que tienes en el estado, no consultes AWS primero".

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**
```powershell
cd $INFRA_DIR

# Paso 1: Vaciar el bucket S3 (Terraform no puede borrar buckets con archivos)
$AccountId = (aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://sanos-y-salvos-frontend-$AccountId" --recursive 2>$null

# Paso 2: Destruir toda la infraestructura
# -refresh=false evita el error de voc-cancel-cred en data sources
terraform destroy -refresh=false -auto-approve
```

⏱️ **Tiempo estimado: 10–15 minutos** (RDS tarda más en eliminarse)

### 13.2 Si Terraform destroy falla (método alternativo con AWS CLI)

Si por alguna razón Terraform no puede destruir, usa este script que elimina todo directamente via AWS CLI:

💻 **PowerShell local:**
```powershell
# Guardar credenciales en variables de entorno de la sesión
$env:AWS_DEFAULT_REGION = "us-east-1"
$AccountId = (aws sts get-caller-identity --query Account --output text)

# 1. Terminar EC2
$instances = aws ec2 describe-instances --filters "Name=tag:Proyecto,Values=sanos-y-salvos" --query "Reservations[].Instances[?State.Name!='terminated'].InstanceId" --output text
if ($instances) { aws ec2 terminate-instances --instance-ids $instances }

# 2. Eliminar ALB + Target Groups
$albArn = aws elbv2 describe-load-balancers --names "sanos-y-salvos-alb" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null
if ($albArn -ne "None") {
    aws elbv2 describe-listeners --load-balancer-arn $albArn --query "Listeners[].ListenerArn" --output text | ForEach-Object { aws elbv2 delete-listener --listener-arn $_ }
    aws elbv2 delete-load-balancer --load-balancer-arn $albArn
    Start-Sleep 30
}
foreach ($tg in @("sanos-y-salvos-tg-bff","sanos-y-salvos-tg-frontend")) {
    $arn = aws elbv2 describe-target-groups --names $tg --query "TargetGroups[0].TargetGroupArn" --output text 2>$null
    if ($arn -ne "None") { aws elbv2 delete-target-group --target-group-arn $arn }
}

# 3. Eliminar RDS y ElastiCache
aws rds delete-db-instance --db-instance-identifier "sanos-y-salvos-postgres" --skip-final-snapshot --delete-automated-backups 2>$null
aws elasticache delete-cache-cluster --cache-cluster-id "sanos-y-salvos-redis" 2>$null

# 4. Eliminar ECR
foreach ($repo in @("auth-service","ms-mascotas","ms-geolocalizacion","ms-coincidencias","bff-service","frontend")) {
    aws ecr delete-repository --repository-name "sanos-y-salvos/$repo" --force 2>$null
}

# 5. Eliminar Secrets Manager y CloudWatch
foreach ($s in @("sanos-y-salvos/db","sanos-y-salvos/redis","sanos-y-salvos/rabbitmq","sanos-y-salvos/jwt")) {
    aws secretsmanager delete-secret --secret-id $s --force-delete-without-recovery 2>$null
}
aws logs delete-log-group --log-group-name "/ecs/sanos-y-salvos" 2>$null

# 6. Vaciar y eliminar S3
aws s3 rm "s3://sanos-y-salvos-frontend-$AccountId" --recursive 2>$null
aws s3api delete-bucket --bucket "sanos-y-salvos-frontend-$AccountId" 2>$null

# 7. Eliminar NAT Gateways y EIPs (esperar que RDS/ElastiCache terminen)
Write-Host "Esperando 3 min para que RDS/ElastiCache se eliminen..." -ForegroundColor Yellow
Start-Sleep -Seconds 180
$nats = aws ec2 describe-nat-gateways --filter "Name=tag:Proyecto,Values=sanos-y-salvos" "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output text
foreach ($nat in $nats -split "`t" | Where-Object {$_}) { aws ec2 delete-nat-gateway --nat-gateway-id $nat }
Start-Sleep 60
$eips = aws ec2 describe-addresses --filters "Name=tag:Proyecto,Values=sanos-y-salvos" --query "Addresses[].AllocationId" --output text
foreach ($eip in $eips -split "`t" | Where-Object {$_}) { aws ec2 release-address --allocation-id $eip }

# 8. Eliminar VPCs (subnets, SGs, route tables, IGW)
$vpcs = aws ec2 describe-vpcs --filters "Name=tag:Proyecto,Values=sanos-y-salvos" --query "Vpcs[].VpcId" --output text
foreach ($vpcId in $vpcs -split "`t" | Where-Object {$_}) {
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[].SubnetId" --output text | ForEach-Object { $_ -split "`t" } | Where-Object {$_} | ForEach-Object { aws ec2 delete-subnet --subnet-id $_ 2>$null }
    aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | ForEach-Object { $_ -split "`t" } | Where-Object {$_} | ForEach-Object { aws ec2 delete-security-group --group-id $_ 2>$null }
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpcId" --query "InternetGateways[].InternetGatewayId" --output text | ForEach-Object { $_ -split "`t" } | Where-Object {$_} | ForEach-Object { aws ec2 detach-internet-gateway --internet-gateway-id $_ --vpc-id $vpcId 2>$null; aws ec2 delete-internet-gateway --internet-gateway-id $_ 2>$null }
    aws ec2 delete-vpc --vpc-id $vpcId 2>$null
}

# 9. Eliminar subnet groups, parameter group, key pair
aws rds delete-db-subnet-group --db-subnet-group-name "sanos-y-salvos-db-subnet-group" 2>$null
aws elasticache delete-cache-subnet-group --cache-subnet-group-name "sanos-y-salvos-redis-subnet-group" 2>$null
aws rds delete-db-parameter-group --db-parameter-group-name "sanos-y-salvos-pg15" 2>$null
aws ec2 delete-key-pair --key-name "sanos-y-salvos-key" 2>$null
Remove-Item "sanos-y-salvos-key.pem" -ErrorAction SilentlyContinue

# 10. Limpiar estado Terraform local
Remove-Item "terraform.tfstate","terraform.tfstate.backup" -ErrorAction SilentlyContinue

Write-Host "=== Limpieza completa ===" -ForegroundColor Green
```

---

## 14. Solución de problemas

### ❌ ExpiredTokenException
**Causa:** Credenciales de Academy caducadas (~4h).
**Solución:** Repite el Paso 3 (actualizar credenciales).

### ❌ database "X" does not exist
**Causa:** RDS no estaba listo cuando EC2 arrancó.
**Solución:** Repite el Paso 6 y luego reinicia los contenedores:
```powershell
ssh -i "sanos-y-salvos-key.pem" -o StrictHostKeyChecking=no "ec2-user@$Ec2Ip" `
    "docker restart auth-service ms-mascotas ms-geolocalizacion ms-coincidencias"
```

### ❌ Docker ECR 400 Bad Request
**Causa:** Docker Desktop usa un `credsStore` incompatible con session tokens.
**Solución:** Repite el bloque del Paso 7.1 para escribir auth directamente.

### ❌ terraform destroy falla con voc-cancel-cred
**Causa:** Política de AWS Academy bloquea `ec2:DescribeImages` e `iam:GetRole`.
**Solución:** Usa siempre `terraform destroy -refresh=false -auto-approve`.

### ❌ Microservicio DOWN en health check
**Causa y solución según componente:**

| Componente DOWN | Significado | Solución |
|---|---|---|
| `db` | No puede conectar a RDS | Verifica que la BD existe (Paso 6) |
| `mail` | Sin servidor SMTP | Normal, no afecta funcionamiento |
| `redis` | No puede conectar a ElastiCache | Verifica `terraform output redis_host` |
| `rabbit` | RabbitMQ no está corriendo | `docker ps` y verifica el contenedor |

### ❌ Frontend carga pero API no responde
**Causa:** `.env.production` tiene la URL del ALB de la sesión anterior.
**Solución:** Repite el Paso 10.1 y vuelve a compilar y subir.

---

## 15. Credenciales y puertos de referencia

### Base de datos RDS
| Variable | Valor |
|---|---|
| Usuario | `sanosadmin` |
| Contraseña | `SanosYSalvos2026!` |
| Puerto | `5432` |
| BDs | `auth_db`, `mascotas_db`, `geolocalizacion_db`, `coincidencias_db` |

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

### Puertos de microservicios
| Servicio | Puerto |
|---|---|
| bff-service | `8080` |
| auth-service | `8081` |
| ms-mascotas | `8082` |
| ms-geolocalizacion | `8083` |
| ms-coincidencias | `8084` |

---

## 16. Checklist rápido

```
INICIO DE SESIÓN
[ ] AWS Academy → Start Lab → luz verde
[ ] Copiar 3 líneas de AWS Details
[ ] PowerShell → sanos_y_salvos\ → .\update-credentials.ps1
[ ] aws sts get-caller-identity → verificar Account ID

INFRAESTRUCTURA (10-15 min)
[ ] aws ec2 create-key-pair → guardar sanos-y-salvos-key.pem
[ ] Renombrar terraform.tfstate si existe
[ ] terraform init -upgrade
[ ] terraform apply -auto-approve
[ ] Anotar: ec2_public_ip, alb_dns, rds_host

COMPILAR Y DOCKERIZAR (10-15 min)
[ ] Docker Desktop corriendo
[ ] cd Sanos-y-Salvos\ → mvn clean package "-Dmaven.test.skip=true"
[ ] Bloque ECR login (Paso 7.1)
[ ] Build y push de las 5 imágenes

BACKEND (5-10 min)
[ ] SSH al EC2 → crear 4 BDs en RDS → exit
[ ] Ejecutar start-services.sh en EC2
[ ] Esperar 3 minutos
[ ] docker ps → 6 contenedores Up

FRONTEND (5 min)
[ ] Actualizar .env.production con nuevo alb_dns
[ ] npm run build
[ ] Crear bucket S3 y sincronizar dist/

VERIFICACIÓN
[ ] .\smoke-test.ps1 → todo verde
[ ] Abrir frontend en navegador
[ ] Registrar usuario de prueba → OK

AL TERMINAR
[ ] aws s3 rm s3://sanos-y-salvos-frontend-<id> --recursive
[ ] terraform destroy -refresh=false -auto-approve
```

---

*Guía educativa — Sanos y Salvos en AWS Academy*
*Repositorio código: `Sanos-y-Salvos` | Repositorio infraestructura: `sanos_y_salvos`*
