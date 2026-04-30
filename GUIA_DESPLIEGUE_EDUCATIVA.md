# 🚀 Guía Educativa de Despliegue — Sanos y Salvos en AWS

> **¿Para qué sirve esta guía?**
> Te explica paso a paso cómo desplegar la aplicación completa en AWS, entendiendo **qué hace cada comando, por qué se hace y qué está ocurriendo internamente**. Al terminar sabrás: cómo funciona Terraform, cómo se orquesta Docker en EC2, y cómo se destruye toda la infraestructura limpiamente.

---

> ## ⚠️ ANTES DE EMPEZAR — ADAPTA LAS RUTAS A TU MÁQUINA
>
> Esta guía usa rutas de ejemplo. **Cada integrante del equipo tiene los repositorios en una ubicación distinta.** Ejecuta este bloque UNA SOLA VEZ al abrir PowerShell para que todos los comandos funcionen sin modificación:
>
> ```powershell
> # ─────────────────────────────────────────────────────────────────
> # PERSONALIZA ESTAS DOS RUTAS según donde clonaste los repositorios
> # ─────────────────────────────────────────────────────────────────
> $INFRA_DIR = "C:\ruta\a\sanos_y_salvos"    # ← repo de infraestructura Terraform
> $CODE_DIR  = "C:\ruta\a\Sanos-y-Salvos"    # ← repo de código fuente (microservicios)
>
> # Ejemplos reales según tu equipo:
> # $INFRA_DIR = "C:\Users\TuUsuario\Documents\sanos_y_salvos"
> # $INFRA_DIR = "D:\Proyectos\sanos_y_salvos"
> # ─────────────────────────────────────────────────────────────────
> ```
>
> Todos los comandos `cd` de esta guía usan `$INFRA_DIR` o `$CODE_DIR`. Si defines las variables una vez, el resto funciona tal cual.

---

## 📐 Arquitectura que vamos a crear

Antes de ejecutar cualquier comando, es importante entender **qué vamos a construir**:

```
INTERNET
    │
    ▼
┌─────────────────────────────────────────┐
│     ALB (Application Load Balancer)     │  ← Punto de entrada único (puerto 80)
│  DNS: sanos-y-salvos-alb-xxxx.elb.      │    Recibe todo el tráfico de internet
└──────────────┬──────────────────────────┘
               │  /api/*  →  puerto 8080
               ▼
┌─────────────────────────────────────────┐
│         EC2 t3.medium (Docker)          │  ← Un servidor que corre 6 contenedores
│                                         │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ bff-service │  │   auth-service  │   │  ← Microservicios Java Spring Boot
│  │   :8080     │  │     :8081       │   │
│  └─────────────┘  └─────────────────┘   │
│  ┌──────────────┐ ┌──────────────────┐  │
│  │ ms-mascotas  │ │ms-geolocalizacion│  │
│  │    :8082     │ │      :8083       │  │
│  └──────────────┘ └──────────────────┘  │
│  ┌────────────────┐ ┌────────────────┐  │
│  │ms-coincidencias│ │   rabbitmq     │  │
│  │     :8084      │ │  :5672/15672   │  │
│  └────────────────┘ └────────────────┘  │
└─────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌──────────────────┐ ┌────────────────────┐
│  RDS PostgreSQL  │ │ ElastiCache Redis  │
│  (subnet privada)│ │  (subnet privada)  │
│                  │ │                    │
│  auth_db         │ │  Sesiones/Cache    │
│  mascotas_db     │ │                    │
│  geolocalizacion │ └────────────────────┘
│  coincidencias   │
└──────────────────┘
         │
         ▼
┌──────────────────┐   ┌────────────────────┐
│   ECR (imágenes  │   │     S3 Buckets     │
│   Docker en AWS) │   │  - fotos mascotas  │
│                  │   │  - frontend React  │
└──────────────────┘   └────────────────────┘
```

**¿Por qué esta arquitectura?**
AWS Academy bloquea ECS Fargate en cuentas de laboratorio, por eso usamos **EC2 con Docker directamente**. Un servidor EC2 `t3.medium` (2 vCPU, 4GB RAM) corre todos los microservicios como contenedores Docker en una red interna.

---

## 📋 Requisitos Previos

### Herramientas necesarias en tu máquina local

| Herramienta | Para qué sirve | Verificar |
|-------------|----------------|-----------|
| **AWS CLI** | Comunicarse con AWS desde terminal | `aws --version` |
| **Terraform** | Crear infraestructura como código | `terraform -v` |
| **Docker Desktop** | Construir imágenes de los microservicios | `docker info` |
| **Java 17 + Maven** | Compilar los microservicios Spring Boot | `mvn -v` |
| **Node.js + npm** | Construir el frontend React | `node -v` |

### Estructura de carpetas esperada

> 📌 La ubicación exacta en tu disco **varía según tu computador**. Lo importante es que existan estos DOS repositorios y que los hayas configurado en `$INFRA_DIR` y `$CODE_DIR` (ver cuadro de aviso al inicio de esta guía).

```
📁 [cualquier ruta en tu disco]/
│
├── 📁 sanos_y_salvos/          ← $INFRA_DIR  (infraestructura Terraform)
│   ├── provider.tf
│   ├── ec2.tf
│   ├── alb.tf
│   ├── credentials.tf  ← ¡NUNCA subir a GitHub!
│   └── ...
│
└── 📁 Sanos-y-Salvos/          ← $CODE_DIR   (código fuente)
    ├── auth-service/
    ├── ms-mascotas/
    ├── ms-geolocalizacion/
    ├── ms-coincidencias/
    ├── bff-service/
    └── frontend/
```

**¿Cómo sé la ruta exacta?** Abre el explorador de archivos, navega hasta la carpeta y copia la ruta desde la barra de direcciones.

---

## 🎓 CONCEPTO CLAVE: ¿Qué es Terraform?

**Terraform** es una herramienta de "Infraestructura como Código" (IaC). En lugar de hacer clic en la consola de AWS para crear recursos, **escribes los recursos en archivos `.tf`** y Terraform los crea automáticamente.

**Ventajas:**
- 🔁 **Reproducible**: El mismo código siempre crea la misma infraestructura
- 📝 **Versionable**: Puedes poner la infraestructura en Git
- 🗑️ **Destruible**: `terraform destroy` elimina TODO lo que creó, sin dejar nada
- 📊 **Estado**: Terraform guarda un archivo `terraform.tfstate` que recuerda qué creó

**Flujo básico:**
```
terraform init   →  terraform plan   →  terraform apply   →  terraform destroy
(descargar        (ver qué va         (crear recursos)      (eliminar todo)
 plugins)          a crear)
```

---

## 📁 Archivos de Infraestructura (resumen)

| Archivo | Qué contiene |
|---------|--------------|
| `provider.tf` | Configura AWS como proveedor (región, credenciales) |
| `variables.tf` | Variables reutilizables (contraseñas, nombres, etc.) |
| `credentials.tf` | Credenciales AWS Academy (¡NO subir a GitHub!) |
| `vpc.tf` | Red privada virtual: subnets, rutas, NAT Gateway |
| `security-groups.tf` | Reglas de firewall (quién puede hablar con quién) |
| `rds.tf` | Base de datos PostgreSQL |
| `elasticache.tf` | Cache Redis |
| `ecr.tf` | Repositorios Docker en AWS |
| `ec2.tf` | Servidor EC2 con Docker |
| `alb.tf` | Load Balancer (enruta tráfico) |
| `s3.tf` | Almacenamiento de archivos |
| `outputs.tf` | Muestra las URLs y datos importantes al terminar |

---

# 🚦 PASO A PASO — DESPLIEGUE COMPLETO

## PASO 0 — Actualizar Credenciales AWS Academy

**¿Por qué?** AWS Academy usa credenciales temporales que **expiran cada ~4 horas**. Hay que renovarlas al inicio de cada sesión de laboratorio.

### Cómo obtener las credenciales:
1. Abre **AWS Academy Learner Lab** en tu navegador
2. Haz clic en **"AWS Details"** (esquina superior derecha del lab)
3. Copia las 3 líneas que aparecen:
   ```
   aws_access_key_id=ASIA...
   aws_secret_access_key=...
   aws_session_token=IQo...
   ```

### Actualizar credenciales con el script:
```powershell
# Navega a la carpeta de infraestructura
cd $INFRA_DIR

# Ejecuta el script de actualización
.\update-credentials.ps1
# → Pega las 3 líneas cuando se solicite y presiona ENTER dos veces
```

**¿Qué hace `update-credentials.ps1`?**
- Lee las 3 líneas del panel AWS Details
- Actualiza el archivo `credentials.tf` con las nuevas claves
- Configura las variables de entorno `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` para que AWS CLI también funcione
- Verifica con `aws sts get-caller-identity` que las credenciales son válidas

**¿Qué es `credentials.tf`?**
```hcl
locals {
  aws_access_key    = "ASIA..."       # Clave de acceso temporal
  aws_secret_key    = "..."           # Clave secreta temporal
  aws_session_token = "IQo..."        # Token de sesión (necesario en Academy)
}
```
Este archivo está en `.gitignore` para que nunca se suba a GitHub con credenciales reales.

### Verificar que funciona:
```powershell
aws sts get-caller-identity
# Respuesta esperada:
# {
#     "UserId": "AROA...",
#     "Account": "895112511964",
#     "Arn": "arn:aws:sts::895112511964:assumed-role/voclabs/..."
# }
```

---

## PASO 1 — Crear el Key Pair para SSH

**¿Por qué?** Para poder conectarte al servidor EC2 via SSH (para debug o ver logs), necesitas un par de claves criptográficas. AWS guarda la clave pública, tú guardas la privada (archivo `.pem`).

**¿Qué es SSH?** Es un protocolo de acceso remoto seguro. Con el `.pem` puedes "entrar" al servidor como si tuvieras teclado y monitor conectados.

```powershell
# Crear el key pair en AWS y descargar la clave privada
aws ec2 create-key-pair `
  --key-name "sanos-y-salvos-key" `
  --query "KeyMaterial" `
  --output text > sanos-y-salvos-key.pem

# Verificar que se creó
Get-Content sanos-y-salvos-key.pem | Select-Object -First 3
# Debe mostrar: -----BEGIN RSA PRIVATE KEY-----
```

**⚠️ IMPORTANTE:** El archivo `sanos-y-salvos-key.pem` es tu llave privada. Si lo pierdes, **no puedes recuperarlo**. En la presentación lo necesitas solo si quieres ver logs del servidor.

---

## PASO 2 — Terraform Init (preparar Terraform)

**¿Qué es `terraform init`?** Es el primer comando que siempre debes ejecutar. Descarga los **plugins/providers** necesarios — en nuestro caso el plugin de AWS.

```powershell
# Posiciónate en la carpeta de infraestructura
cd $INFRA_DIR

# Inicializar Terraform
terraform init
```

**¿Qué descarga?**
- `hashicorp/aws` v5.x — Plugin oficial de AWS para Terraform
- Crea la carpeta `.terraform/` con los binarios descargados
- Crea `.terraform.lock.hcl` que "congela" las versiones de los plugins

**Salida esperada:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

---

## PASO 3 — Terraform Plan (ver qué se va a crear)

**¿Qué es `terraform plan`?** Muestra un "plan de ejecución" — **qué recursos va a crear, modificar o destruir** — SIN hacer ningún cambio real. Es como un "modo vista previa".

```powershell
terraform plan
```

**Salida esperada (resumen):**
```
Plan: 47 to add, 0 to change, 0 to destroy.
```

**¿Qué significa cada símbolo?**
- `+` verde = recurso que se va a CREAR
- `~` amarillo = recurso que se va a MODIFICAR
- `-` rojo = recurso que se va a DESTRUIR

**¿Por qué usarlo?** Para revisar que Terraform va a hacer lo que esperas **antes** de ejecutarlo. En producción real nunca se hace `apply` sin revisar el `plan` primero.

---

## PASO 4 — Terraform Apply (crear toda la infraestructura)

**¿Qué es `terraform apply`?** Ejecuta el plan y **crea todos los recursos en AWS**. Este paso tarda entre 10-15 minutos porque RDS y ElastiCache tardan en inicializarse.

```powershell
terraform apply -auto-approve
```

**¿Qué hace `-auto-approve`?** Omite la confirmación manual (que normalmente requiere escribir `yes`). En presentación es útil para ahorrar tiempo.

### Recursos que se crean (en orden aproximado):

#### 🌐 Red (VPC) — primero porque todo lo demás depende de ella
```
aws_vpc.main                     → Red privada virtual 10.0.0.0/16
aws_subnet.publica_az_a          → Subnet pública AZ-a (10.0.1.0/24) — ALB y EC2
aws_subnet.publica_az_b          → Subnet pública AZ-b (10.0.2.0/24) — ALB HA
aws_subnet.privada_az_a          → Subnet privada AZ-a (10.0.3.0/24) — RDS, Redis
aws_subnet.privada_az_b          → Subnet privada AZ-b (10.0.4.0/24) — RDS, Redis HA
aws_internet_gateway.main        → Puerta a internet
aws_eip.nat                      → IP estática para el NAT Gateway
aws_nat_gateway.main             → Permite que subnets privadas salgan a internet
aws_route_table.publica          → Ruta: 0.0.0.0/0 → Internet Gateway
aws_route_table.privada          → Ruta: 0.0.0.0/0 → NAT Gateway
```

**¿Por qué subnets públicas Y privadas?**
- **Pública**: El ALB y EC2 necesitan IP pública para recibir tráfico de internet
- **Privada**: RDS y Redis NO deben ser accesibles directamente desde internet (seguridad)
- El NAT Gateway permite que RDS/Redis hagan solicitudes salientes (actualizaciones) sin exponer puertos de entrada

#### 🔥 Security Groups (firewall) — antes de los recursos que los usan
```
aws_security_group.alb           → ALB: permite tráfico HTTP/S de internet
aws_security_group.ec2           → EC2: permite SSH y puertos 8080-8084 desde ALB
aws_security_group.rds           → RDS: solo acepta PostgreSQL (5432) desde EC2
aws_security_group.redis         → Redis: solo acepta 6379 desde EC2
```

**Concepto de Security Group:** Es un firewall virtual. Define reglas de `ingress` (entrada) y `egress` (salida). Por defecto todo está bloqueado; solo abres lo necesario.

#### 🐘 RDS PostgreSQL — puede tardar 5-8 minutos
```
aws_db_instance.main             → PostgreSQL 15, db.t3.micro, 20GB
aws_db_subnet_group.main         → Grupo de subnets donde vive la BD
aws_db_parameter_group.main      → Configuración de PostgreSQL
```

**¿Por qué tarda tanto?** AWS aprovisiona hardware real, instala PostgreSQL, configura alta disponibilidad (HA) y hace un snapshot inicial. El comando `apply` **espera** a que esté listo antes de continuar.

#### 🔴 ElastiCache Redis — puede tardar 3-5 minutos
```
aws_elasticache_cluster.redis    → Redis 7, cache.t3.micro
aws_elasticache_subnet_group.main → Grupo de subnets donde vive Redis
```

**¿Para qué usamos Redis?** Auth-service guarda las sesiones y tokens JWT en Redis. Es mucho más rápido que buscarlos en la base de datos en cada petición.

#### 📦 ECR (Docker Registry) — instantáneo
```
aws_ecr_repository.servicios["auth-service"]
aws_ecr_repository.servicios["ms-mascotas"]
aws_ecr_repository.servicios["ms-geolocalizacion"]
aws_ecr_repository.servicios["ms-coincidencias"]
aws_ecr_repository.servicios["bff-service"]
aws_ecr_repository.servicios["frontend"]
```

**¿Qué es ECR?** Elastic Container Registry — es como Docker Hub pero privado dentro de AWS. Guardaremos aquí las imágenes Docker de los microservicios.

#### 🖥️ EC2 — instantáneo en Terraform, pero tarda ~3-4 min en arrancar
```
aws_instance.backend             → t3.medium, Amazon Linux 2023, con user-data.sh
aws_lb_target_group_attachment.bff → Registra el EC2 en el Load Balancer
```

**¿Qué hace `user-data.sh`?** Es un script que se ejecuta automáticamente la primera vez que arranca el EC2. Instala Docker, configura swap, hace login a ECR y arranca todos los microservicios.

#### ⚖️ ALB — después del EC2
```
aws_lb.main                      → Application Load Balancer
aws_lb_target_group.bff          → Target group para bff-service (puerto 8080)
aws_lb_listener.http             → Escucha en puerto 80, redirige a S3 por defecto
aws_lb_listener_rule.api         → /api/* → Target group BFF
```

#### 🗄️ S3 — almacenamiento de fotos
```
aws_s3_bucket.fotos              → Bucket para fotos de mascotas subidas por usuarios
```

**Salida final esperada (outputs):**
```
Outputs:

alb_dns = "sanos-y-salvos-alb-123456789.us-east-1.elb.amazonaws.com"
ec2_public_ip = "54.87.xxx.xxx"
rds_host = "sanos-y-salvos-rds.xxxxx.us-east-1.rds.amazonaws.com"
redis_host = "sanos-y-salvos-redis.xxxxx.0001.use1.cache.amazonaws.com"
s3_bucket = "sanos-y-salvos-fotos-895112511964"
url_aplicacion = "http://sanos-y-salvos-alb-123456789.us-east-1.elb.amazonaws.com"
```

**¡Guarda estos valores!** Los necesitarás en los siguientes pasos.

---

## PASO 5 — Crear Bases de Datos en RDS

**¿Por qué?** Terraform crea el **servidor** PostgreSQL, pero no las **bases de datos individuales** dentro de él. Cada microservicio necesita su propia BD aislada.

**¿Qué es un "DB subnet group"?** Le dice a RDS en qué subnets puede vivir. Al ser subnets privadas, nadie desde internet puede conectarse directamente.

```powershell
# Ejecutar el script que crea los schemas
.\init-database.ps1
```

**¿Qué hace `init-database.ps1` internamente?**
1. Lee el host de RDS del output de Terraform
2. Se conecta a PostgreSQL con `psql` o via el EC2 como puente
3. Ejecuta `init-databases.sql` que contiene:

```sql
-- Crear 4 bases de datos (una por microservicio)
CREATE DATABASE auth_db;
CREATE DATABASE mascotas_db;
CREATE DATABASE geolocalizacion_db;
CREATE DATABASE coincidencias_db;

-- En auth_db: tablas de usuarios y autenticación
\c auth_db
CREATE TABLE roles (id SERIAL PRIMARY KEY, nombre VARCHAR(50) UNIQUE NOT NULL);
CREATE TABLE users (id BIGSERIAL PRIMARY KEY, email VARCHAR(255) UNIQUE, ...);
INSERT INTO roles (nombre) VALUES ('ADMIN'), ('USER');

-- En mascotas_db: tablas de mascotas y reportes
\c mascotas_db
CREATE TABLE mascotas (id BIGSERIAL PRIMARY KEY, nombre VARCHAR(100), ...);
CREATE TABLE reportes (id BIGSERIAL PRIMARY KEY, mascota_id BIGINT, ...);

-- En geolocalizacion_db: ubicaciones con coordenadas GPS
\c geolocalizacion_db
CREATE EXTENSION IF NOT EXISTS postgis;  -- Extensión para datos geoespaciales
CREATE TABLE ubicaciones_reporte (id BIGSERIAL PRIMARY KEY, latitud DOUBLE PRECISION, ...);

-- En coincidencias_db: coincidencias entre mascotas perdidas y encontradas
\c coincidencias_db
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- Extensión para búsqueda por similitud
CREATE TABLE coincidencias (id BIGSERIAL PRIMARY KEY, score FLOAT, ...);
```

**¿Por qué PostgreSQL y no MySQL?** PostGIS (extensión de datos geoespaciales para coordenadas GPS) solo está disponible en PostgreSQL. Lo usamos para calcular distancias entre mascotas perdidas y reportes de mascotas encontradas.

---

## PASO 6 — Construir Imágenes Docker y Subir a ECR

**¿Qué es una imagen Docker?** Una imagen Docker es un "snapshot" de una aplicación con todo lo que necesita para funcionar (Java, dependencias, código compilado). Los contenedores son instancias en ejecución de esa imagen.

**¿Por qué subir a ECR?** El EC2 en AWS no puede acceder a tu Docker local. Necesitamos subir las imágenes a ECR (Docker Registry privado de AWS) para que el EC2 las descargue.

### 6.1 — Login a ECR

```powershell
# Obtener el Account ID
$AccountId = (aws sts get-caller-identity --query Account --output text)

# Login a ECR (las credenciales duran 12 horas)
aws ecr get-login-password --region us-east-1 | `
  docker login --username AWS --password-stdin `
  "$AccountId.dkr.ecr.us-east-1.amazonaws.com"

# Salida esperada: Login Succeeded
```

**¿Cómo funciona el login a ECR?**
- `aws ecr get-login-password` obtiene un token temporal de AWS
- `docker login` lo usa como contraseña para autenticarse en el registry privado
- A partir de ahí, `docker push` y `docker pull` funcionan automáticamente

### 6.2 — Compilar los microservicios (Maven Build)

```powershell
# Ir a la carpeta de los microservicios
cd $CODE_DIR

# Compilar todos los servicios (puede tardar 10-15 min la primera vez)
mvn clean package -DskipTests --no-transfer-progress
```

**¿Qué hace Maven?**
1. `clean` — Elimina compilaciones anteriores
2. `package` — Compila el código Java y crea un `.jar` ejecutable
3. `-DskipTests` — Omite los tests para ir más rápido (en producción real NO se haría esto)
4. El resultado son archivos como `auth-service/target/auth-service-0.0.1-SNAPSHOT.jar`

**¿Qué es un JAR?** Java ARchive — un archivo comprimido con todo el código compilado y las dependencias. Con `java -jar auth-service.jar` arranca el microservicio.

### 6.3 — Construir y subir cada imagen Docker

```powershell
$AccountId = (aws sts get-caller-identity --query Account --output text)
$EcrBase   = "$AccountId.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos"

$servicios = @("auth-service", "ms-mascotas", "ms-geolocalizacion", "ms-coincidencias", "bff-service")

foreach ($svc in $servicios) {
    Write-Host "--- Procesando $svc ---" -ForegroundColor Cyan

    # 1. Construir imagen desde el Dockerfile del servicio
    docker build -t "$EcrBase/$svc`:latest" ".\$svc\"

    # 2. Subir imagen a ECR
    docker push "$EcrBase/$svc`:latest"

    Write-Host "[OK] $svc subido a ECR" -ForegroundColor Green
}
```

**¿Qué hace un Dockerfile?** Define cómo construir la imagen:
```dockerfile
# Ejemplo simplificado de un Dockerfile de un microservicio
FROM eclipse-temurin:17-jre-alpine    # Imagen base con Java 17
WORKDIR /app                           # Directorio de trabajo
COPY target/*.jar app.jar              # Copia el JAR compilado
EXPOSE 8081                            # Puerto que expone
ENTRYPOINT ["java", "-jar", "app.jar"] # Comando de inicio
```

**¿Por qué `eclipse-temurin:17-jre-alpine`?**
- `eclipse-temurin:17` — Java 17 de OpenJDK (versión recomendada para Spring Boot 3)
- `jre` en lugar de `jdk` — Solo el runtime (más pequeño, sin compilador)
- `alpine` — Imagen Linux minimalista (mucho más pequeña, más segura)

---

## PASO 7 — Iniciar Microservicios en el EC2

El EC2 ya está corriendo (desde el PASO 4). El `user-data.sh` intentó arrancar los servicios pero **las imágenes aún no estaban en ECR**. Ahora que subimos las imágenes, hay que ejecutar el script de inicio:

```powershell
# Obtener la IP pública del EC2
$Ec2Ip = (terraform output -raw ec2_public_ip)

# Conectarse via SSH y ejecutar el script de inicio
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "/home/ec2-user/start-services.sh"
```

**¿O usar el script de registro automático?**
```powershell
.\register-backend.ps1
```

**¿Qué hace `start-services.sh` en el EC2?**
1. Re-hace login a ECR
2. Hace `docker pull` de cada imagen
3. Ejecuta `docker run` con todas las variables de entorno necesarias:
   - `DB_HOST` — Host de RDS
   - `REDIS_HOST` — Host de Redis
   - `RABBITMQ_HOST` — Hostname del contenedor RabbitMQ
   - `JWT_SECRET` — Clave para firmar tokens de autenticación
   - `JAVA_TOOL_OPTIONS` — Limita memoria de cada JVM (256MB máx)

**¿Por qué limitar memoria de Java?** Cada microservicio Spring Boot necesita ~400MB por defecto. Con 5 servicios = 2GB solo en JVMs. En una instancia de 4GB eso deja muy poco margen. Con `-Xmx256m` limitamos a 256MB por servicio.

**¿Qué es RabbitMQ?** Es un message broker (intermediario de mensajes). Los microservicios lo usan para comunicarse de forma asíncrona. Por ejemplo, cuando se crea un reporte de mascota perdida, `ms-mascotas` publica un mensaje en RabbitMQ, y `ms-coincidencias` lo recibe para buscar coincidencias — sin que los dos servicios tengan que conocerse directamente.

### Ver logs del EC2 para verificar que todo arrancó:

```powershell
# Ver log de bootstrap (instalación Docker, init BD)
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "tail -f /var/log/sanos-deploy.log"

# Ver log de los microservicios
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "tail -f /var/log/sanos-services.log"

# Ver logs de un servicio específico
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "docker logs auth-service -f --tail 50"

# Ver todos los contenedores corriendo
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "docker ps"
```

**Salida esperada de `docker ps`:**
```
CONTAINER ID   IMAGE                                    STATUS          PORTS
abc123         .../bff-service:latest                   Up 5 minutes    0.0.0.0:8080->8080/tcp
def456         .../auth-service:latest                  Up 5 minutes    0.0.0.0:8081->8081/tcp
ghi789         .../ms-mascotas:latest                   Up 5 minutes    0.0.0.0:8082->8082/tcp
jkl012         .../ms-geolocalizacion:latest            Up 5 minutes    0.0.0.0:8083->8083/tcp
mno345         .../ms-coincidencias:latest              Up 5 minutes    0.0.0.0:8084->8084/tcp
pqr678         rabbitmq:3.12-alpine                     Up 10 minutes   0.0.0.0:5672->5672/tcp
```

---

## PASO 8 — Deploy del Frontend React a S3

**¿Por qué S3 y no el EC2?** Los archivos estáticos (HTML, CSS, JS) no necesitan un servidor de aplicaciones. S3 puede servirlos directamente a millones de usuarios, es gratuito para almacenamiento pequeño, y es más rápido.

```powershell
# Obtener el DNS del ALB
$AlbDns = (terraform output -raw alb_dns)
$AccountId = (aws sts get-caller-identity --query Account --output text)
$S3Bucket = "sanos-y-salvos-frontend-$AccountId"

# Ir a la carpeta del frontend
cd "$CODE_DIR\frontend"

# Configurar la URL de la API (el ALB enruta /api/* al bff-service)
"VITE_API_BASE_URL=http://$AlbDns/api" | Out-File .env.production -Encoding utf8

# Compilar el frontend (genera archivos estáticos en dist/)
npm install
npm run build
# → Crea la carpeta dist/ con index.html, JS, CSS optimizados

# Crear bucket S3 para el frontend
aws s3api create-bucket --bucket $S3Bucket --region us-east-1

# Desactivar el bloqueo de acceso público
aws s3api delete-public-access-block --bucket $S3Bucket

# Agregar política de acceso público (necesaria para hosting estático)
$policy = @"
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
$policy | aws s3api put-bucket-policy --bucket $S3Bucket --policy file:///dev/stdin

# Habilitar hosting estático en S3
aws s3 website "s3://$S3Bucket" --index-document index.html --error-document index.html

# Subir todos los archivos
aws s3 sync dist/ "s3://$S3Bucket" --delete

Write-Host "Frontend disponible en: http://$S3Bucket.s3-website-us-east-1.amazonaws.com"
```

**¿Qué es `npm run build`?** Compila el código React (JSX, TypeScript) en archivos JavaScript estáticos que cualquier navegador puede ejecutar. Vite (el bundler) también:
- Minifica el código (elimina espacios, acorta nombres)
- Divide el código en chunks pequeños (code splitting)
- Optimiza imágenes

**¿Qué es hosting estático en S3?** S3 tiene una función donde sirve archivos como si fuera un servidor web. Cuando alguien accede a `http://bucket.s3-website-us-east-1.amazonaws.com`, S3 devuelve el `index.html` automáticamente.

---

## PASO 9 — Verificar que todo funciona (Smoke Test)

```powershell
# Ejecutar smoke test automático
.\smoke-test.ps1
```

**O manualmente:**

```powershell
$AlbDns = (terraform output -raw alb_dns)
$Ec2Ip  = (terraform output -raw ec2_public_ip)

# 1. Verificar BFF (punto de entrada de la API)
Invoke-RestMethod "http://$AlbDns/api/actuator/health"
# Esperado: {"status":"UP"}

# 2. Verificar auth-service directamente
Invoke-RestMethod "http://$Ec2Ip`:8081/actuator/health"
# Esperado: {"status":"UP","components":{"db":{"status":"UP"},"redis":{"status":"UP"}}}

# 3. Registrar un usuario de prueba
$body = @{ email="test@test.com"; password="Test1234!"; nombre="Test" } | ConvertTo-Json
Invoke-RestMethod "http://$AlbDns/api/auth/register" -Method POST -Body $body -ContentType "application/json"

# 4. Verificar frontend (S3)
$AccountId  = (aws sts get-caller-identity --query Account --output text)
$S3Endpoint = "http://sanos-y-salvos-frontend-$AccountId.s3-website-us-east-1.amazonaws.com"
(Invoke-WebRequest $S3Endpoint).StatusCode   # Esperado: 200
```

**¿Qué es `/actuator/health`?** Spring Boot Actuator es una librería que expone endpoints de monitoreo. `/health` devuelve el estado de la aplicación y sus dependencias (BD, Redis). Si algo falla, aparece en el JSON.

---

## PASO 10 — Usar el script maestro (todo automatizado)

Si quieres que todo se ejecute solo sin hacer los pasos uno a uno:

```powershell
# Deploy completo (~45-60 min primera vez)
.\master-deploy.ps1

# Solo hacer push de imágenes (Terraform ya corrió)
.\master-deploy.ps1 -SkipTerraform

# Omitir build de Docker (imágenes ya están en ECR)
.\master-deploy.ps1 -SkipBuild

# Sin deploy de frontend
.\master-deploy.ps1 -SkipFrontend
```

---

# 🗑️ DESTRUIR TODA LA INFRAESTRUCTURA CON TERRAFORM

> **¿Cuándo destruir?** Al final de la presentación, cuando termines de usar AWS Academy. Así liberas recursos y evitas cargos (aunque en Academy no cobran, es buena práctica).

## El comando mágico:

```powershell
cd $INFRA_DIR

terraform destroy -auto-approve
```

**¿Qué hace `terraform destroy`?**
1. Lee el archivo `terraform.tfstate` (recuerda qué recursos creó)
2. Calcula el orden de destrucción (inverso al de creación, respetando dependencias)
3. Elimina **cada recurso** llamando a la API de AWS
4. Al terminar, `terraform.tfstate` queda vacío

**Orden de destrucción (simplificado):**
```
1. EC2 → registro en ALB (target group attachment)
2. ALB → listeners y reglas
3. ALB → target groups
4. ALB → Load Balancer
5. ElastiCache → cluster Redis
6. RDS → instancia PostgreSQL
7. Secrets Manager → secrets
8. ECR → repositorios (si están vacíos)
9. S3 → bucket de fotos
10. Security Groups → todos
11. NAT Gateway + Elastic IP
12. Subnets → privadas y públicas
13. Route Tables → pública y privada
14. Internet Gateway
15. VPC → la red en sí
```

**¿Por qué este orden importa?** Terraform es inteligente — no puede eliminar la VPC si todavía hay recursos dentro de ella. Destruye los "hijos" antes que los "padres". Este árbol de dependencias lo calculó automáticamente durante el `apply`.

**Tiempo estimado:** 10-15 minutos (RDS tarda ~5 min en eliminarse)

## Verificar que no quedó nada:

```powershell
# Verificar que no hay instancias EC2
aws ec2 describe-instances --filters "Name=tag:Proyecto,Values=sanos-y-salvos" `
  --query "Reservations[].Instances[].InstanceId"
# Esperado: []

# Verificar que no hay ALBs
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName,'sanos')]"
# Esperado: []

# Verificar que no hay RDS
aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier,'sanos')]"
# Esperado: []
```

## Eliminar recursos que Terraform NO controla:

```powershell
# El bucket de frontend lo creamos con AWS CLI, hay que borrarlo manualmente
$AccountId = (aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://sanos-y-salvos-frontend-$AccountId" --recursive
aws s3api delete-bucket --bucket "sanos-y-salvos-frontend-$AccountId"

# El key pair
aws ec2 delete-key-pair --key-name "sanos-y-salvos-key"
Remove-Item "sanos-y-salvos-key.pem" -ErrorAction SilentlyContinue

Write-Host "Todo eliminado." -ForegroundColor Green
```

**¿Por qué algunos recursos no los destruye Terraform?** Solo destruye lo que **él creó**. El bucket de frontend lo creamos con `aws s3api create-bucket` en el script, no con Terraform, así que no está en el `tfstate`.

---

## ⚡ RESUMEN EJECUTIVO (para el día de la presentación)

```
┌─────────────────────────────────────────────────────┐
│  CHECKLIST DÍA DE PRESENTACIÓN                      │
├─────────────────────────────────────────────────────┤
│ □ 1. Abrir AWS Academy Lab                          │
│ □ 2. .\update-credentials.ps1 (pegar 3 líneas)     │
│ □ 3. aws ec2 create-key-pair ... > key.pem          │
│ □ 4. terraform init (solo si es la primera vez)     │
│ □ 5. terraform apply -auto-approve  (~10-15 min)    │
│ □ 6. (Esperar que RDS termine de crear)             │
│ □ 7. mvn clean package -DskipTests  (~10-15 min)    │
│ □ 8. docker build + docker push (5 servicios)       │
│ □ 9. register-backend.ps1 (iniciar servicios en EC2)│
│ □ 10. deploy-frontend.ps1 (frontend a S3)           │
│ □ 11. smoke-test.ps1 (verificar todo)               │
│ □ 12. Abrir http://<ALB_DNS> en el navegador 🎉     │
├─────────────────────────────────────────────────────┤
│  AL TERMINAR:                                       │
│ □ terraform destroy -auto-approve                   │
│ □ Eliminar bucket frontend y key pair manualmente   │
└─────────────────────────────────────────────────────┘

ALTERNATIVA RÁPIDA:
    .\master-deploy.ps1
(hace los pasos 4-11 automáticamente)
```

---

## 🔧 Solución de Problemas Comunes

### ❌ "The key pair 'sanos-y-salvos-key' does not exist"
**Causa:** Olvidaste crear el key pair antes de hacer `terraform apply`.
```powershell
aws ec2 create-key-pair --key-name "sanos-y-salvos-key" --query KeyMaterial --output text > sanos-y-salvos-key.pem
terraform apply -auto-approve
```

### ❌ "InvalidClientTokenId" o "ExpiredTokenException"
**Causa:** Credenciales AWS Academy expiradas.
```powershell
.\update-credentials.ps1
```

### ❌ Contenedor no arranca ("Error: manifest unknown")
**Causa:** La imagen no está en ECR todavía.
```powershell
# Verificar qué imágenes hay en ECR
aws ecr list-images --repository-name sanos-y-salvos/auth-service

# Volver a hacer push si falta
docker push $EcrBase/auth-service:latest

# Re-ejecutar start-services.sh en EC2
ssh -i sanos-y-salvos-key.pem ec2-user@$Ec2Ip "/home/ec2-user/start-services.sh"
```

### ❌ BFF responde 503 en el ALB
**Causa:** El contenedor bff-service no está healthy aún (los Spring Boot tardan ~60-90 seg en arrancar).
```powershell
# Esperar 2 minutos y volver a intentar
Start-Sleep -Seconds 120
Invoke-RestMethod "http://$AlbDns/api/actuator/health"
```

### ❌ "Error creating DB Instance: InvalidParameterCombination"
**Causa:** Versión de PostgreSQL o clase de instancia no disponible en Academy.
```powershell
# Ver las versiones disponibles
aws rds describe-db-engine-versions --engine postgres --query "DBEngineVersions[].EngineVersion"
# Ajustar en rds.tf si es necesario
```

### ❌ `terraform destroy` falla en recursos que ya no existen
**Causa:** Alguien los borró manualmente (o la sesión de Academy terminó).
```powershell
# Eliminar el recurso del state sin intentar borrarlo de AWS
terraform state rm aws_db_instance.main
# Luego volver a correr destroy
terraform destroy -auto-approve
```

---

## 📚 Glosario Rápido

| Término | Significado |
|---------|-------------|
| **VPC** | Virtual Private Cloud — red privada aislada en AWS |
| **Subnet** | Subdivisión de una VPC. "Pública" = acceso internet, "Privada" = sin acceso directo |
| **IGW** | Internet Gateway — "puerta" entre la VPC e internet |
| **NAT Gateway** | Permite que subnets privadas SALGAN a internet sin recibir tráfico entrante |
| **Security Group** | Firewall virtual — controla qué tráfico entra/sale de un recurso |
| **ALB** | Application Load Balancer — distribuye tráfico HTTP entre servidores |
| **Target Group** | Conjunto de servidores que reciben tráfico del ALB |
| **EC2** | Elastic Compute Cloud — máquina virtual en AWS |
| **RDS** | Relational Database Service — base de datos administrada |
| **ElastiCache** | Cache administrado (Redis o Memcached) |
| **ECR** | Elastic Container Registry — Docker Hub privado de AWS |
| **IAM** | Identity and Access Management — gestión de permisos en AWS |
| **LabRole** | Rol IAM pre-creado en AWS Academy con permisos limitados |
| **tfstate** | Archivo donde Terraform guarda el estado de lo que creó |
| **user-data** | Script que se ejecuta automáticamente al arrancar un EC2 |
| **Docker** | Plataforma de contenedores — empaqueta apps con sus dependencias |
| **Spring Boot** | Framework Java para crear microservicios REST rápidamente |
| **RabbitMQ** | Message broker — intermediario para mensajes entre microservicios |
| **JWT** | JSON Web Token — token cifrado para autenticar usuarios sin sesión |
| **PostGIS** | Extensión PostgreSQL para datos geoespaciales (coordenadas GPS) |
