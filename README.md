# Sanos y Salvos — Infraestructura AWS con Terraform

> Arquitectura serverless: **API Gateway → Lambda × 5 → RDS · Redis · SQS · S3**  
> Desplegable en AWS Academy sin permisos de creación de roles IAM.

---

## Diagrama de despliegue

```mermaid
graph TD
  Internet -->|HTTPS| APIGW["AWS API Gateway HTTP API"]

  APIGW -->|ANY /api/auth/*| LambdaAuth["λ auth-service"]
  APIGW -->|ANY /api/mascotas/*| LambdaMascotas["λ ms-mascotas"]
  APIGW -->|ANY /api/geo/*| LambdaGeo["λ ms-geolocalizacion"]
  APIGW -->|ANY /api/coincidencias/*| LambdaCoinc["λ ms-coincidencias"]
  APIGW -->|ANY /api/*| LambdaBFF["λ bff-service"]

  LambdaMascotas -->|publica evento| SQS1["SQS: reportes-nuevos"]
  SQS1 -->|trigger| LambdaGeo
  LambdaGeo -->|publica evento| SQS2["SQS: geo-completados"]
  SQS2 -->|trigger| LambdaCoinc
  LambdaCoinc -->|notificación| SQS3["SQS: notificaciones"]

  LambdaAuth --> RDS["RDS PostgreSQL 15\n(Multi-AZ)"]
  LambdaMascotas --> RDS
  LambdaGeo --> RDS
  LambdaCoinc --> RDS
  LambdaBFF --> RDS

  LambdaAuth --> Redis["ElastiCache Redis"]
  LambdaBFF --> Redis

  LambdaMascotas --> S3["S3: fotos mascotas"]

  ECR["ECR: imágenes Docker"] -->|image_uri| LambdaAuth
  ECR -->|image_uri| LambdaMascotas
  ECR -->|image_uri| LambdaGeo
  ECR -->|image_uri| LambdaCoinc
  ECR -->|image_uri| LambdaBFF

  subgraph VPC ["VPC — us-east-1 (2 AZs)"]
    subgraph AZ_A ["us-east-1a (primaria)"]
      LambdaAuth
      LambdaMascotas
      LambdaGeo
      LambdaCoinc
      LambdaBFF
    end
    subgraph AZ_B ["us-east-1b (respaldo automático)"]
      RDS
      Redis
    end
  end
```

---

## Archivos Terraform

| Archivo | Descripción |
|---|---|
| `provider.tf` | AWS provider, región us-east-1 |
| `variables.tf` | Variables (proyecto, DB, región, etc.) |
| `credentials.tf` | ⚠️ **NO en GitHub** — credenciales temporales Academy |
| `vpc.tf` | VPC, subnets privadas/públicas (2 AZs), IGW, NAT |
| `security-groups.tf` | SGs para Lambda, RDS, Redis |
| `rds.tf` | RDS PostgreSQL 15 (Multi-AZ standby) |
| `elasticache.tf` | ElastiCache Redis 7 |
| `ecr.tf` | Repositorios ECR (uno por microservicio) |
| `s3.tf` | Bucket S3 para fotos de mascotas |
| `sqs.tf` | Colas SQS (reportes-nuevos, geo-completados, notificaciones + DLQs) |
| `lambda.tf` | 5 funciones Lambda + SQS event source mappings |
| `api-gateway.tf` | HTTP API Gateway + rutas + permisos |
| `outputs.tf` | URLs, ARNs y datos de conexión útiles |

---

## Pasos para desplegar desde cero

### 1. Actualiza credenciales

Edita `credentials.tf` con los datos de tu sesión actual de AWS Academy (**AWS Details → AWS CLI**):

```hcl
locals {
  aws_access_key    = "ASIA..."
  aws_secret_key    = "..."
  aws_session_token = "..."
}
```

### 2. Inicializa y aplica Terraform

```sh
terraform init
terraform apply -auto-approve
```

Tarda **10–15 minutos**. Crea: VPC · subnets · SGs · RDS · Redis · ECR · SQS · Lambdas · API Gateway.

Al terminar, guarda los outputs:

```sh
terraform output
```

El dato más importante es `api_endpoint` — es el punto de entrada de la aplicación.

### 3. Construye y publica las imágenes Docker en ECR

```sh
# Login a ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build y push de cada microservicio (repetir para los otros 4)
cd ../Sanos-y-Salvos
docker build -t auth-service ./auth-service
docker tag auth-service:latest <ECR_URL>/auth-service:latest
docker push <ECR_URL>/auth-service:latest
```

Las URLs ECR las encuentras en `terraform output ecr_urls`.

### 4. Recarga las funciones Lambda con la nueva imagen

```sh
aws lambda update-function-code --function-name sanos-y-salvos-auth-service --image-uri <ECR_URL>/auth-service:latest
aws lambda update-function-code --function-name sanos-y-salvos-bff-service --image-uri <ECR_URL>/bff-service:latest
aws lambda update-function-code --function-name sanos-y-salvos-ms-mascotas --image-uri <ECR_URL>/ms-mascotas:latest
aws lambda update-function-code --function-name sanos-y-salvos-ms-geolocalizacion --image-uri <ECR_URL>/ms-geolocalizacion:latest
aws lambda update-function-code --function-name sanos-y-salvos-ms-coincidencias --image-uri <ECR_URL>/ms-coincidencias:latest
```

### 5. Inicializa las bases de datos en RDS

```sh
psql -h <RDS_HOST> -U sanosadmin -d postgres -f init-databases.sql
```

El `RDS_HOST` lo encuentras en `terraform output rds_host`.

### 6. Verifica la aplicación

```sh
# La URL del API Gateway (sin trailing slash)
API=$(terraform output -raw api_endpoint)

# Catálogo de especies (sin JWT)
curl $API/api/mascotas/especies

# Login
curl -X POST $API/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test1234!"}'
```

---

## Notas importantes

- **Sin EC2 ni RabbitMQ** — La arquitectura es 100% serverless. No hay instancias que mantener.
- **Lambda Web Adapter** — Cada microservicio Spring Boot corre dentro de Lambda sin cambios de código. El adaptador (`public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4`) traduce los eventos HTTP de API Gateway en peticiones HTTP estándar.
- **SQS reemplaza RabbitMQ** — Flujo async: `ms-mascotas` publica en `reportes-nuevos` → Lambda trigger en `ms-geolocalizacion` → publica en `geo-completados` → Lambda trigger en `ms-coincidencias`.
- **Alta disponibilidad** — Lambdas en VPC con subnets en 2 AZs. Si `us-east-1a` falla, AWS redirige invocaciones a `us-east-1b` automáticamente.
- **AWS Academy compatible** — Todas las Lambdas usan `LabRole` (existente). No se crea ningún rol IAM nuevo.
- **Credenciales expiran** — Las credenciales Academy duran ~4 horas. Si aparece `ExpiredTokenException`, actualiza `credentials.tf` y ejecuta `terraform apply` nuevamente.

---

## Estructura del modelo de datos (mascotas_db)

```
especies (id, nombre)          → PERRO, GATO, AVE, CONEJO, OTRO
  └─> razas (id, especie_id, nombre)    → Labrador, Siamés, etc.
         └─> reportes (id, tipo, especie_id, raza_id, ...)
               ├── tipo = "PERDIDO"   → campos recompensa
               └── tipo = "ENCONTRADO" → campos lugar_resguardo, tiene_collar
```

---

## Repositorio de Microservicios

El código fuente de los microservicios está en:  
`../Sanos-y-Salvos/` (Repositorio separado)
