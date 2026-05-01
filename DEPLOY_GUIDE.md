# Guía Completa de Despliegue — Sanos y Salvos en AWS Academy

> **Arquitectura:** API Gateway HTTP API → 5 Lambda functions → RDS · Redis · SQS · S3  
> **Tiempo estimado:** 30–45 minutos la primera vez.  
> **Importante:** AWS Academy borra toda la infraestructura al cerrar la sesión. Esta guía permite recrearla desde cero cada vez.

---

## Convenciones de esta guía

Cada bloque de comandos indica **dónde** ejecutarlo:

| Ícono | Significa |
|---|---|
| 💻 **PowerShell local** | Terminal PowerShell en tu computador |
| 🔵 **CMD / Git Bash local** | Terminal normal en tu computador |
| ☁️ **AWS CLI** | Cualquier terminal con credenciales configuradas |
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
8. [Paso 5 — Recargar las funciones Lambda](#8-paso-5--recargar-las-funciones-lambda)
9. [Paso 6 — Inicializar bases de datos en RDS](#9-paso-6--inicializar-bases-de-datos-en-rds)
10. [Paso 7 — Desplegar el frontend en S3](#10-paso-7--desplegar-el-frontend-en-s3)
11. [Paso 8 — Verificación final](#11-paso-8--verificación-final)
12. [Cómo funciona la mensajería SQS](#12-cómo-funciona-la-mensajería-sqs)
13. [Modelo de datos](#13-modelo-de-datos)
14. [Acceso a las bases de datos](#14-acceso-a-las-bases-de-datos)
15. [Solución de problemas frecuentes](#15-solución-de-problemas-frecuentes)
16. [Destruir la infraestructura](#16-destruir-la-infraestructura)
17. [Variables y credenciales de referencia](#17-variables-y-credenciales-de-referencia)
18. [Checklist rápido](#18-checklist-rápido)

---

## 1. Arquitectura general

```
Internet (HTTPS)
  └─> AWS API Gateway HTTP API
        ├── ANY /api/auth/{proxy+}          → Lambda: auth-service       (puerto 8081)
        ├── ANY /api/mascotas/{proxy+}      → Lambda: ms-mascotas         (puerto 8082)
        ├── ANY /api/geo/{proxy+}           → Lambda: ms-geolocalizacion  (puerto 8083)
        ├── ANY /api/coincidencias/{proxy+} → Lambda: ms-coincidencias    (puerto 8084)
        └── ANY /api/{proxy+}               → Lambda: bff-service         (puerto 8080, fallback)

Flujo asíncrono (SQS — reemplaza RabbitMQ):
  ms-mascotas ──publica──> SQS: reportes-nuevos
                                  └─> Lambda trigger ──> ms-geolocalizacion
                                                              └──publica──> SQS: geo-completados
                                                                                  └─> Lambda trigger ──> ms-coincidencias
                                                                                                              └──publica──> SQS: notificaciones

RDS PostgreSQL 15 (Multi-AZ: us-east-1a primaria / us-east-1b standby)
  ├── auth_db            → usuarios, roles, tokens
  ├── mascotas_db        → reportes, especies, razas
  ├── geolocalizacion_db → ubicaciones + PostGIS
  └── coincidencias_db   → coincidencias + pg_trgm

ElastiCache Redis 7  → sesiones JWT y caché BFF
S3 bucket            → fotos de mascotas + frontend estático
ECR                  → imágenes Docker (una por microservicio)
CloudWatch Logs      → logs de cada Lambda (/aws/lambda/sanos-*)

Alta disponibilidad:
  Lambdas en VPC con subnets en us-east-1a Y us-east-1b
  → si una AZ falla, AWS redirige invocaciones a la otra AZ automáticamente
  → RDS failover automático a standby en ~60 segundos
```

**¿Por qué Lambda en lugar de EC2?**

| Aspecto | EC2 + Docker (anterior) | Lambda (actual) |
|---|---|---|
| Escalado | Manual, instancia fija | Automático por petición |
| Alta disponibilidad | Una sola AZ activa | Multi-AZ nativo |
| Mantenimiento | SSH, actualizaciones OS | Cero — AWS gestiona todo |
| Costo | Instancia siempre encendida | Solo pagas por invocación |
| AWS Academy compatible | ✅ | ✅ (usa LabRole existente) |
| RabbitMQ | ❌ Requiere contenedor extra | ✅ SQS gestionado, sin servidor |

---

## 2. Prerequisitos

Instala estas herramientas **en tu computador local** antes de empezar:

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| AWS CLI | v2 | https://aws.amazon.com/cli/ |
| Terraform | 1.5+ | https://developer.hashicorp.com/terraform/downloads |
| Docker Desktop | Cualquiera | https://www.docker.com/products/docker-desktop/ |
| Java JDK | 21 | https://adoptium.net/ |
| Maven | 3.8+ | https://maven.apache.org/download.cgi |
| Node.js + npm | 18+ | https://nodejs.org/ |
| Git | Cualquiera | https://git-scm.com/ |
| psql (PostgreSQL client) | 15+ | https://www.postgresql.org/download/ |

💻 **PowerShell local** — Verifica que todo esté instalado:

```powershell
aws --version
terraform -v
docker --version
java -version
mvn -version
node --version
npm --version
psql --version
```

---

## 3. Estructura de repositorios

El proyecto usa **dos repositorios** que deben estar clonados en tu computador:

```
Sanos y salvos/
├── Sanos-y-Salvos/              ← código fuente microservicios + frontend
│   ├── auth-service/
│   │   └── Dockerfile           ← incluye Lambda Web Adapter
│   ├── ms-mascotas/
│   │   └── Dockerfile           ← incluye Lambda Web Adapter
│   ├── ms-geolocalizacion/
│   │   └── Dockerfile           ← incluye Lambda Web Adapter
│   ├── ms-coincidencias/
│   │   └── Dockerfile           ← incluye Lambda Web Adapter
│   ├── bff-service/
│   │   └── Dockerfile           ← incluye Lambda Web Adapter
│   └── frontend/
│
└── sanos_y_salvos/              ← infraestructura Terraform  ← ESTÁS AQUÍ
    ├── provider.tf
    ├── variables.tf
    ├── credentials.tf            ← ⚠️ NO en GitHub — crear manualmente
    ├── vpc.tf
    ├── security-groups.tf
    ├── rds.tf
    ├── elasticache.tf
    ├── ecr.tf
    ├── s3.tf
    ├── sqs.tf                   ← 3 colas SQS + DLQs
    ├── lambda.tf                ← 5 funciones Lambda
    ├── api-gateway.tf           ← HTTP API + rutas
    ├── outputs.tf
    ├── init-databases.sql
    ├── update-credentials.ps1
    └── deploy-frontend.ps1
```

💻 **PowerShell local** — Clona los repositorios si aún no los tienes:

```powershell
mkdir "C:\proyectos\sanos-y-salvos"
cd "C:\proyectos\sanos-y-salvos"

git clone https://github.com/tu-org/Sanos-y-Salvos.git
git clone https://github.com/tu-org/sanos_y_salvos.git
```

---

## 4. Paso 1 — Obtener credenciales AWS Academy

### 4.1 Obtener las credenciales desde el portal

1. Ingresa a **AWS Academy Learner Lab**
2. Haz clic en **Start Lab** y espera que el ícono quede en **verde**
3. Haz clic en **AWS Details** (panel derecho)
4. Copia las 3 líneas: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`
5. Anota tu **Account ID** (12 dígitos) visible en la consola AWS arriba a la derecha

### 4.2 Actualizar credenciales con el script

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
.\update-credentials.ps1
```

El script te pedirá que pegues las 3 líneas de AWS Details y actualizará `credentials.tf` automáticamente.

### 4.3 Verificar que las credenciales funcionan

☁️ **AWS CLI:**

```powershell
aws sts get-caller-identity
```

Deberías ver tu Account ID en la respuesta. Si da error, repite el paso 4.2.

> **Importante:** Las credenciales de AWS Academy expiran cada ~4 horas. Si algo falla con `ExpiredTokenException`, repite los pasos 4.2 y 4.3.

---

## 5. Paso 2 — Crear infraestructura con Terraform

### 5.1 Asegúrate de que Docker Desktop esté corriendo

Ábrelo desde el menú inicio. Espera a que el ícono de la ballena quede **estático** (no animado).

### 5.2 Limpiar el estado anterior de Terraform

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

> Esto es necesario porque AWS Academy asigna una cuenta nueva en cada sesión.

### 5.3 Inicializar y aplicar Terraform

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

terraform init -upgrade

terraform apply -auto-approve
```

Esto tarda **10–15 minutos**. Crea:
- VPC con subnets privadas y públicas en 2 AZs
- Security Groups para Lambda, RDS, Redis
- RDS PostgreSQL 15 (Multi-AZ)
- ElastiCache Redis
- ECR (5 repositorios)
- S3 (fotos + frontend)
- SQS (3 colas + 2 DLQs)
- 5 funciones Lambda
- API Gateway HTTP API con 5 rutas

Al terminar verás los outputs. Guárdalos:

```powershell
terraform output > outputs-$(Get-Date -Format 'yyyyMMdd').txt
terraform output
```

**Output más importante:**
```
api_gateway_url = "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com"
rds_host        = "sanos-y-salvos-postgres.xxxx.us-east-1.rds.amazonaws.com"
```

> **Si hay error `ResourceNotFoundException` en Lambda:** Las imágenes ECR aún no existen. Es normal — las Lambdas quedan en estado `pending` hasta el paso 5.

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

# Compilar todos los microservicios en paralelo
$servicios = @("auth-service", "ms-mascotas", "ms-geolocalizacion", "ms-coincidencias", "bff-service")

foreach ($s in $servicios) {
    Write-Host "Compilando $s..."
    Set-Location $s
    mvn clean package -DskipTests -q
    Set-Location ..
    Write-Host "✅ $s compilado"
}
```

O compila individualmente:

```powershell
cd auth-service          && mvn clean package -DskipTests && cd ..
cd ms-mascotas           && mvn clean package -DskipTests && cd ..
cd ms-geolocalizacion    && mvn clean package -DskipTests && cd ..
cd ms-coincidencias      && mvn clean package -DskipTests && cd ..
cd bff-service           && mvn clean package -DskipTests && cd ..
```

---

## 7. Paso 4 — Construir y publicar imágenes Docker en ECR

### 7.1 Login a ECR

☁️ **AWS CLI** — usa el comando del output `ecr_login_command`:

```powershell
# Obtener el comando exacto de Terraform output
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
terraform output -raw ecr_login_command | Invoke-Expression
```

O manualmente (reemplaza `<ACCOUNT_ID>`):
```powershell
aws ecr get-login-password --region us-east-1 | `
  docker login --username AWS --password-stdin `
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

### 7.2 Obtener las URLs de ECR

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
terraform output docker_push_commands
```

Ejemplo de salida:
```
{
  "auth-service"       = "docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest"
  "bff-service"        = "docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/bff-service:latest"
  "ms-coincidencias"   = "docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ms-coincidencias:latest"
  "ms-geolocalizacion" = "docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ms-geolocalizacion:latest"
  "ms-mascotas"        = "docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ms-mascotas:latest"
}
```

### 7.3 Build y push de cada microservicio

📁 **Directorio:** `Sanos-y-Salvos/`

Reemplaza `<ECR_BASE>` con tu URL base (p.ej. `123456789012.dkr.ecr.us-east-1.amazonaws.com`):

```powershell
$ECR_BASE = "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com"

$servicios = @(
    @{ nombre = "auth-service";       carpeta = "auth-service" },
    @{ nombre = "bff-service";        carpeta = "bff-service" },
    @{ nombre = "ms-mascotas";        carpeta = "ms-mascotas" },
    @{ nombre = "ms-geolocalizacion"; carpeta = "ms-geolocalizacion" },
    @{ nombre = "ms-coincidencias";   carpeta = "ms-coincidencias" }
)

foreach ($s in $servicios) {
    Write-Host "🐳 Build y push: $($s.nombre)..."
    docker build -t $s.nombre ./$($s.carpeta)
    docker tag "$($s.nombre):latest" "$ECR_BASE/$($s.nombre):latest"
    docker push "$ECR_BASE/$($s.nombre):latest"
    Write-Host "✅ $($s.nombre) publicado"
}
```

> **¿Por qué las imágenes funcionan en Lambda?**  
> Cada Dockerfile incluye esta línea en el stage final:
> ```dockerfile
> COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter
> ```
> El **Lambda Web Adapter** convierte los eventos HTTP de API Gateway en peticiones HTTP estándar que Spring Boot procesa normalmente. **No hay cambios de código en los microservicios.**

---

## 8. Paso 5 — Recargar las funciones Lambda

Después de subir las imágenes a ECR, actualiza cada Lambda para que use la nueva imagen:

☁️ **AWS CLI:**

```powershell
$ACCOUNT_ID = "<tu-account-id>"
$ECR_BASE   = "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"

$lambdas = @(
    @{ fn = "sanos-auth-service";       img = "auth-service" },
    @{ fn = "sanos-bff-service";        img = "bff-service" },
    @{ fn = "sanos-ms-mascotas";        img = "ms-mascotas" },
    @{ fn = "sanos-ms-geolocalizacion"; img = "ms-geolocalizacion" },
    @{ fn = "sanos-ms-coincidencias";   img = "ms-coincidencias" }
)

foreach ($l in $lambdas) {
    Write-Host "🔄 Actualizando Lambda: $($l.fn)..."
    aws lambda update-function-code `
        --function-name $l.fn `
        --image-uri "$ECR_BASE/$($l.img):latest" | Out-Null
    Write-Host "✅ $($l.fn) actualizado"
}
```

Espera ~30 segundos y verifica que están activas:

```powershell
aws lambda list-functions --query "Functions[?starts_with(FunctionName, 'sanos')].{Nombre:FunctionName, Estado:State}" --output table
```

---

## 9. Paso 6 — Inicializar bases de datos en RDS

### 9.1 Obtener el host de RDS

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"
$RDS_HOST = terraform output -raw rds_host
Write-Host "RDS Host: $RDS_HOST"
```

### 9.2 Ejecutar el script SQL

El script `init-databases.sql` crea las 4 bases de datos, tablas, índices y datos iniciales (roles, estados, especies, razas):

🔵 **CMD / Git Bash:**

```bash
psql -h $RDS_HOST -U sanosadmin -d postgres -f init-databases.sql
```

💻 **PowerShell:**

```powershell
$env:PGPASSWORD = "tu-password-rds"
psql -h $RDS_HOST -U sanosadmin -d postgres -f init-databases.sql
```

> **Nota:** Si no puedes conectarte a RDS directamente (la instancia está en subred privada), necesitas un **bastion host** o tunnel SSH. Para AWS Academy, la manera más sencilla es crear temporalmente un EC2 en la subred pública, hacer SSH y ejecutar el psql desde allí.

### 9.3 Verificar la inicialización

```sql
-- Conectarse a mascotas_db y verificar
psql -h $RDS_HOST -U sanosadmin -d mascotas_db -c "
SELECT e.nombre AS especie, count(r.id) AS razas
FROM especies e
LEFT JOIN razas r ON r.especie_id = e.id
GROUP BY e.nombre ORDER BY e.nombre;
"
```

Deberías ver las 5 especies (PERRO, GATO, AVE, CONEJO, OTRO) con sus razas.

---

## 10. Paso 7 — Desplegar el frontend en S3

### 10.1 Compilar el frontend

📁 **Directorio:** `Sanos-y-Salvos/frontend/`

```powershell
cd "C:\proyectos\sanos-y-salvos\Sanos-y-Salvos\frontend"

# Configura la URL de la API (usa tu api_gateway_url real)
$API_URL = (terraform -chdir="../../sanos_y_salvos" output -raw api_gateway_url)
"VITE_API_URL=$API_URL" | Out-File -FilePath ".env.production" -Encoding utf8

npm install
npm run build
```

### 10.2 Subir al bucket S3

☁️ **AWS CLI:**

```powershell
$BUCKET = (terraform -chdir="../../sanos_y_salvos" output -raw s3_bucket)
aws s3 sync dist/ s3://$BUCKET/ --delete --cache-control "max-age=31536000" --exclude "index.html"
aws s3 cp dist/index.html s3://$BUCKET/index.html --cache-control "no-cache"
```

### 10.3 Obtener la URL del frontend

```powershell
Write-Host "Frontend URL: http://$BUCKET.s3-website-us-east-1.amazonaws.com"
```

---

## 11. Paso 8 — Verificación final

### 11.1 Probar el API Gateway

```powershell
$API = (terraform -chdir="C:\proyectos\sanos-y-salvos\sanos_y_salvos" output -raw api_gateway_url)

# 1. Catálogo de especies (sin autenticación)
Invoke-RestMethod -Uri "$API/api/mascotas/especies" -Method GET

# 2. Catálogo de razas de perros
Invoke-RestMethod -Uri "$API/api/mascotas/razas?especieId=1" -Method GET

# 3. Health check del BFF
Invoke-RestMethod -Uri "$API/api/health" -Method GET
```

### 11.2 Probar autenticación

```powershell
# Registrar usuario de prueba
$body = @{
    nombre   = "Test Usuario"
    email    = "test@test.com"
    password = "Test1234!"
} | ConvertTo-Json

$resp = Invoke-RestMethod -Uri "$API/api/auth/register" -Method POST `
    -ContentType "application/json" -Body $body

Write-Host "Registro: $($resp | ConvertTo-Json)"

# Login
$login = @{ email = "test@test.com"; password = "Test1234!" } | ConvertTo-Json
$token = (Invoke-RestMethod -Uri "$API/api/auth/login" -Method POST `
    -ContentType "application/json" -Body $login).token
Write-Host "Token JWT obtenido: $($token.Substring(0,20))..."
```

### 11.3 Probar creación de reporte

```powershell
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$reporte = @{
    tipo        = "PERDIDO"
    especieId   = 1          # PERRO
    razaId      = 1          # Labrador Retriever
    nombre      = "Rocky"
    color       = "Marrón"
    tamano      = "GRANDE"
    descripcion = "Perdido en el parque"
    lat         = -33.4489
    lng         = -70.6693
    recompensa  = 50000
} | ConvertTo-Json

$nuevo = Invoke-RestMethod -Uri "$API/api/mascotas/reportes" `
    -Method POST -Headers $headers -Body $reporte
Write-Host "Reporte creado: $($nuevo.id)"
```

### 11.4 Verificar logs en CloudWatch

En la consola AWS:  
1. Ve a **CloudWatch → Log Groups**
2. Busca `/aws/lambda/sanos-ms-mascotas`
3. Verifica que aparece el log de la petición

O desde CLI:
```powershell
aws logs tail /aws/lambda/sanos-ms-mascotas --follow
aws logs tail /aws/lambda/sanos-ms-geolocalizacion --follow
```

### 11.5 Verificar flujo SQS

```powershell
# Ver mensajes en cola (si quedan sin procesar)
$queueUrl = (terraform -chdir="C:\proyectos\sanos-y-salvos\sanos_y_salvos" output -raw sqs_reportes_nuevos_url)
aws sqs get-queue-attributes --queue-url $queueUrl `
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
```

---

## 12. Cómo funciona la mensajería SQS

**Flujo completo de un reporte perdido:**

```
1. POST /api/mascotas/reportes  (usuario crea reporte)
        │
        ▼
   λ ms-mascotas
   - Guarda reporte en mascotas_db (especie_id=1, raza_id=1)
   - Publica ReporteNuevoEvent en SQS "reportes-nuevos"
   - Responde HTTP 201 al cliente (inmediato)
        │
        ▼ (asíncrono — segundos después)
   λ ms-geolocalizacion  (trigger SQS)
   - Recibe ReporteNuevoEvent (con especie="PERRO", raza="Labrador" como strings)
   - Guarda UbicacionReporte en geolocalizacion_db
   - Geocodifica la dirección
   - Calcula clusters espaciales
   - Publica GeoCompletadoEvent en SQS "geo-completados"
        │
        ▼ (asíncrono — segundos después)
   λ ms-coincidencias  (trigger SQS)
   - Recibe GeoCompletadoEvent
   - Busca reportes ENCONTRADO similares dentro de 5km
   - Calcula score: color + distancia + raza + tamaño
   - Guarda coincidencias en coincidencias_db
   - Publica notificación en SQS "notificaciones"
```

**Variables de entorno relevantes:**

| Variable | Dónde se usa | Valor |
|---|---|---|
| `SQS_REPORTES_NUEVOS_URL` | ms-mascotas | URL SQS del output Terraform |
| `SQS_GEO_COMPLETADOS_URL` | ms-geolocalizacion, ms-mascotas | URL SQS del output Terraform |
| `SQS_NOTIFICACIONES_URL` | ms-coincidencias | URL SQS del output Terraform |

Estas variables se inyectan automáticamente por Terraform en cada Lambda (ver `lambda.tf` → `environment.variables`).

---

## 13. Modelo de datos

### mascotas_db

```sql
-- Catálogos normalizados (reemplazan strings hardcodeados)
especies (id SERIAL PK, nombre VARCHAR(50) UNIQUE)
  → PERRO, GATO, AVE, CONEJO, OTRO

razas (id SERIAL PK, especie_id FK→especies, nombre VARCHAR(100))
  → Labrador Retriever, Golden Retriever, Siamés, etc.

-- Single Table Inheritance (Hibernate discriminator)
reportes (
  id UUID PK,
  tipo VARCHAR(31),          -- "PERDIDO" | "ENCONTRADO"
  user_id UUID,              -- FK lógica → auth_db.users
  especie_id INTEGER FK → especies,
  raza_id INTEGER FK → razas (nullable),
  nombre, color, tamano, descripcion, foto_url,
  estado VARCHAR(20),        -- ACTIVO | INACTIVO | RESUELTO
  lat, lng, direccion, fecha_evento,
  -- Solo para PERDIDO:
  recompensa NUMERIC(38,2),
  -- Solo para ENCONTRADO:
  lugar_resguardo, tiene_collar BOOLEAN
)
```

### Endpoints del catálogo (sin autenticación)

```
GET /api/mascotas/especies           → [{"id":1,"nombre":"PERRO"}, ...]
GET /api/mascotas/razas?especieId=1  → [{"id":1,"nombre":"Labrador Retriever"}, ...]
```

### Crear un reporte (con autenticación)

```json
POST /api/mascotas/reportes
{
  "tipo": "PERDIDO",
  "especieId": 1,
  "razaId": 1,
  "nombre": "Rocky",
  "color": "Marrón con blanco",
  "tamano": "GRANDE",
  "descripcion": "Collar azul, muy amigable",
  "lat": -33.4489,
  "lng": -70.6693,
  "recompensa": 50000
}
```

Respuesta:
```json
{
  "id": "uuid-...",
  "tipo": "PERDIDO",
  "especieId": 1,
  "especieNombre": "PERRO",
  "razaId": 1,
  "razaNombre": "Labrador Retriever",
  "nombre": "Rocky",
  ...
}
```

---

## 14. Acceso a las bases de datos

### Opciones de conexión

**Opción A — Bastion host temporal (recomendado para Academy)**

```powershell
# 1. Lanzar EC2 temporal en la subred pública
aws ec2 run-instances `
    --image-id ami-0c02fb55956c7d316 `
    --instance-type t3.micro `
    --subnet-id <PUBLIC_SUBNET_ID> `
    --security-group-ids <SG_ID> `
    --key-name sanos-y-salvos-key `
    --query "Instances[0].InstanceId" --output text

# 2. Obtener IP pública
aws ec2 describe-instances --instance-ids <ID> `
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text

# 3. SSH + psql
ssh -i sanos-y-salvos-key.pem ec2-user@<EC2_IP>
psql -h <RDS_HOST> -U sanosadmin -d mascotas_db

# 4. Terminar cuando termines
aws ec2 terminate-instances --instance-ids <ID>
```

**Opción B — SSH Tunnel local**

```bash
# Crea el tunnel (requiere acceso SSH a algún host en la VPC)
ssh -i sanos-y-salvos-key.pem -L 5433:<RDS_HOST>:5432 ec2-user@<BASTION_IP> -N &

# Conectar vía tunnel
psql -h localhost -p 5433 -U sanosadmin -d auth_db
```

### Consultas útiles

```sql
-- Ver todos los reportes con especie y raza
\c mascotas_db
SELECT r.id, r.tipo, e.nombre AS especie, rz.nombre AS raza,
       r.nombre, r.estado, r.created_at
FROM reportes r
JOIN especies e ON e.id = r.especie_id
LEFT JOIN razas rz ON rz.id = r.raza_id
ORDER BY r.created_at DESC
LIMIT 20;

-- Ver coincidencias calculadas
\c coincidencias_db
SELECT c.id, c.score_total, c.distancia_km, ce.nombre AS estado,
       cs.score_color, cs.score_geo, cs.score_raza
FROM coincidencias c
JOIN coincidencia_estados ce ON ce.id = c.estado_id
LEFT JOIN coincidencia_scores cs ON cs.coincidencia_id = c.id
ORDER BY c.score_total DESC;

-- Ver usuarios registrados
\c auth_db
SELECT u.id, u.nombre, u.email, r.name AS rol, u.created_at
FROM users u JOIN roles r ON r.id = u.rol_id
ORDER BY u.created_at DESC;
```

---

## 15. Solución de problemas frecuentes

### ❌ Lambda devuelve 502 Bad Gateway

**Causa:** La imagen Docker en ECR no tiene el Lambda Web Adapter, o el puerto `ENV PORT` no coincide con el servidor Spring Boot.

**Solución:**
1. Verifica que el Dockerfile tenga la línea:
   ```dockerfile
   COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter
   ENV PORT=808X   # X = puerto del microservicio
   ```
2. Reconstruye la imagen y vuelve a subir a ECR
3. Actualiza la Lambda: `aws lambda update-function-code --function-name sanos-ms-mascotas --image-uri <ECR_URL>:latest`

### ❌ Lambda timeout (Task timed out after X seconds)

**Causa:** El microservicio Spring Boot tarda más que el timeout configurado (30s para BFF/auth, 60s para mascotas, 120s para geo/coincidencias).

**Solución:**
```hcl
# En lambda.tf, aumentar timeout
resource "aws_lambda_function" "mascotas" {
  timeout = 120   # aumentar si es necesario
  ...
}
```
Luego `terraform apply`.

### ❌ Error de conexión a RDS desde Lambda

**Causa:** La Lambda y el RDS están en VPCs/subnets/SGs incompatibles.

**Solución:**
1. Verifica que la Lambda esté en las subnets privadas: `aws lambda get-function-configuration --function-name sanos-ms-mascotas`
2. Verifica que el SG del RDS tenga regla de entrada desde el SG de Lambda (puerto 5432)
3. En `security-groups.tf`, confirmar:
   ```hcl
   ingress {
     from_port       = 5432
     to_port         = 5432
     protocol        = "tcp"
     security_groups = [aws_security_group.lambda.id]
   }
   ```

### ❌ SQS messages no se procesan (Lambda geo no se dispara)

**Causa:** Falta el event source mapping entre SQS y Lambda, o la Lambda no tiene permisos.

**Solución:**
```powershell
# Ver event source mappings
aws lambda list-event-source-mappings --function-name sanos-ms-geolocalizacion

# Si no hay ninguno, re-aplicar Terraform
terraform apply -target=aws_lambda_event_source_mapping.sqs_geo
```

### ❌ ExpiredTokenException

**Causa:** Credenciales de AWS Academy expiradas.

**Solución:**
```powershell
.\update-credentials.ps1
aws sts get-caller-identity  # verificar
terraform apply -auto-approve  # re-aplicar si es necesario
```

### ❌ Error al compilar (mvn): ClassNotFoundException

**Causa:** La versión de Java no es 21.

**Solución:**
```powershell
java -version  # debe mostrar 21.x
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.x.x.x-hotspot"
```

### ❌ API Gateway devuelve CORS error en el navegador

**Causa:** El CORS está configurado en API Gateway pero el microservicio también está respondiendo headers CORS duplicados.

**Solución:**  
En Spring Boot, verifica que `@CrossOrigin` no esté duplicando los headers con los que API Gateway ya agrega. Generalmente es mejor dejar solo el CORS de API Gateway y remover `@CrossOrigin` de los controllers.

### ❌ Imágenes no aparecen en la app (S3)

**Causa:** Las fotos de mascotas se guardan en S3 con `PutObject`, pero el bucket no tiene acceso público.

**Solución:**
```powershell
$BUCKET = (terraform output -raw s3_bucket)
aws s3api put-bucket-policy --bucket $BUCKET --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::'"$BUCKET"'/*"
  }]
}'
```

---

## 16. Destruir la infraestructura

Al finalizar la sesión de trabajo (no es necesario en Academy ya que se borra automáticamente, pero es buena práctica):

📁 **Directorio:** `sanos_y_salvos/`

💻 **PowerShell local:**

```powershell
cd "C:\proyectos\sanos-y-salvos\sanos_y_salvos"

# Ver qué se va a destruir
terraform plan -destroy

# Destruir todo
terraform destroy -auto-approve
```

> **Nota Academy:** Al cerrar la sesión del Learner Lab, todos los recursos se destruyen automáticamente. Sin embargo, el **bucket S3** y el **RDS** a veces persisten — verifica en la consola AWS.

---

## 17. Variables y credenciales de referencia

### Variables de entorno de cada Lambda (inyectadas por Terraform)

| Variable | Microservicio | Descripción |
|---|---|---|
| `DB_HOST` | Todos | Host de RDS PostgreSQL |
| `DB_USER` | Todos | Usuario DB (sanosadmin) |
| `DB_PASS` | Todos | Password DB |
| `REDIS_HOST` | BFF, auth | Host ElastiCache Redis |
| `JWT_SECRET` | auth, bff | Clave para firmar tokens JWT |
| `SQS_REPORTES_NUEVOS_URL` | mascotas | URL cola SQS |
| `SQS_GEO_COMPLETADOS_URL` | geo, mascotas | URL cola SQS |
| `SQS_NOTIFICACIONES_URL` | coincidencias | URL cola SQS |
| `MINIO_ENDPOINT` | mascotas | `https://s3.amazonaws.com` |
| `MINIO_BUCKET` | mascotas | Nombre del bucket S3 |
| `AUTH_SERVICE_URL` | bff | URL interna vía API Gateway |
| `MASCOTAS_SERVICE_URL` | bff | URL interna vía API Gateway |
| `GEO_SERVICE_URL` | bff | URL interna vía API Gateway |
| `COINCIDENCIAS_SERVICE_URL` | bff | URL interna vía API Gateway |

### Puertos de los microservicios

| Microservicio | Puerto | Lambda function name |
|---|---|---|
| bff-service | 8080 | `sanos-bff-service` |
| auth-service | 8081 | `sanos-auth-service` |
| ms-mascotas | 8082 | `sanos-ms-mascotas` |
| ms-geolocalizacion | 8083 | `sanos-ms-geolocalizacion` |
| ms-coincidencias | 8084 | `sanos-ms-coincidencias` |

### Outputs de Terraform más útiles

```powershell
terraform output api_gateway_url          # URL pública del API Gateway
terraform output rds_host                 # Host del RDS
terraform output redis_host               # Host del Redis
terraform output s3_bucket                # Nombre del bucket
terraform output ecr_login_command        # Comando login ECR
terraform output docker_push_commands     # Comandos push ECR
terraform output lambda_functions         # ARNs de las Lambdas
terraform output sqs_reportes_nuevos_url  # URL cola SQS
terraform output resumen_nueva_arquitectura
```

---

## 18. Checklist rápido

Usa este checklist para verificar que el despliegue está completo:

```
□ Credenciales AWS Academy actualizadas en credentials.tf
□ terraform apply exitoso (sin errores)
□ terraform output muestra api_gateway_url y rds_host
□ Login a ECR exitoso
□ Imágenes Docker construidas para los 5 microservicios
□ Imágenes subidas a ECR (5 repositorios)
□ Lambdas actualizadas con las nuevas imágenes
□ init-databases.sql ejecutado exitosamente
□ GET /api/mascotas/especies devuelve lista de especies
□ POST /api/auth/register crea usuario
□ POST /api/auth/login devuelve JWT token
□ POST /api/mascotas/reportes crea reporte con especieId/razaId
□ CloudWatch Logs de ms-geolocalizacion muestra procesamiento SQS
□ CloudWatch Logs de ms-coincidencias muestra coincidencias calculadas
□ Frontend accesible desde URL S3
```

---

*Guía actualizada para la arquitectura Lambda + SQS + API Gateway — Mayo 2025.*
