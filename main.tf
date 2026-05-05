# ================================================================
# SANOS Y SALVOS — Infraestructura AWS Lambda Serverless
# ================================================================
#
# Archivos Terraform organizados por componente:
#
# Networking:
#   vpc.tf                — VPC, subnets (2 AZs), IGW, NAT
#   security-groups.tf    — SGs para Lambda, RDS, Redis, API Gateway
#
# Datos:
#   rds.tf               — PostgreSQL 15 (Multi-AZ)
#   elasticache.tf       — Redis 7 (Multi-AZ)
#   s3.tf                — Fotos mascotas + frontend estático
#
# Compute & Messaging:
#   lambda.tf            — 5 funciones Lambda (serverless)
#   sqs.tf               — 3 colas SQS + DLQs (mensajería)
#   api-gateway.tf       — HTTP API v2 (punto de entrada)
#
# Contenedores & Credenciales:
#   ecr.tf               — Registros Docker para imágenes Lambda
#   iam.tf               — Referencias a LabRole (AWS Academy)
#   credentials.tf       — Credenciales AWS Academy (gitignore)
#
# Configuración & Outputs:
#   provider.tf          — AWS provider
#   variables.tf         — Variables reutilizables
#   outputs.tf           — Valores de salida para despliegue
#   init-databases.sql   — Schema inicial (ejecutar manualmente)
# ================================================================