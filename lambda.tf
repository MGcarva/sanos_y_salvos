# ================================================================
# LAMBDA — Funciones serverless por microservicio
# Reemplaza EC2+Docker como plataforma de ejecución
#
# Ventajas sobre EC2:
# - Escala automáticamente con la carga
# - 2 AZs activas por defecto (si una cae, Lambda usa la otra)
# - Sin gestión de servidor
# - Compatible con AWS Academy (usa LabRole existente)
#
# Patrón usado: Lambda Web Adapter
# Los microservicios Spring Boot NO necesitan código nuevo —
# el Lambda Web Adapter traduce eventos API Gateway → HTTP requests
# ================================================================

# ================================================================
# SECURITY GROUP PARA LAMBDAS
# Las Lambdas necesitan salir a: RDS, Redis, SQS, S3, ECR
# Las reglas de ingreso a RDS/Redis se agregan al final de este archivo
# ================================================================

resource "aws_security_group" "lambda" {
  name        = "${var.proyecto}-sg-lambda"
  description = "Lambdas: acceso a RDS, Redis, SQS (sin ingreso publico)"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida sin restricciones (RDS, Redis, SQS, S3, ECR)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-lambda"
    Proyecto = var.proyecto
  }
}

# Permitir que las Lambdas alcancen PostgreSQL
resource "aws_security_group_rule" "rds_desde_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "PostgreSQL desde Lambdas"
}

# Permitir que las Lambdas alcancen Redis
resource "aws_security_group_rule" "redis_desde_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "Redis desde Lambdas"
}

# ================================================================
# LOCALS — Valores compartidos entre todas las Lambdas
# ================================================================

locals {
  ecr_base = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.proyecto}"

  # Variables de entorno comunes a todos los microservicios
  lambda_common_env = {
    DB_HOST                 = aws_db_instance.main.address
    DB_USER                 = var.db_username
    DB_PASS                 = var.db_password
    REDIS_HOST              = aws_elasticache_cluster.redis.cache_nodes[0].address
    REDIS_PASS              = var.redis_password
    JWT_SECRET              = var.jwt_secret
    MINIO_ENDPOINT          = "https://s3.amazonaws.com"
    MINIO_BUCKET            = local.s3_bucket_name
    SQS_REPORTES_NUEVOS_URL = aws_sqs_queue.reportes_nuevos.url
    SQS_GEO_COMPLETADOS_URL = aws_sqs_queue.geo_completados.url
    SQS_NOTIFICACIONES_URL  = aws_sqs_queue.notificaciones.url
    AWS_REGION_NAME         = var.region
  }

  lambda_vpc_config = {
    subnet_ids         = [aws_subnet.privada_az_a.id, aws_subnet.privada_az_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# ================================================================
# LAMBDA 1: bff-service
# Punto de entrada HTTP principal — proxy hacia los demás servicios
# Puerto 8080
# ================================================================

resource "aws_lambda_function" "bff" {
  function_name = "${var.proyecto}-bff-service"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_base}/bff-service:latest"
  timeout       = 30
  memory_size   = 512

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = merge(local.lambda_common_env, {
      # URLs internas vía API Gateway (otras Lambdas)
      AUTH_SERVICE_URL          = "${aws_apigatewayv2_api.main.api_endpoint}/api/auth"
      MASCOTAS_SERVICE_URL      = "${aws_apigatewayv2_api.main.api_endpoint}/api/mascotas"
      GEO_SERVICE_URL           = "${aws_apigatewayv2_api.main.api_endpoint}/api/geo"
      COINCIDENCIAS_SERVICE_URL = "${aws_apigatewayv2_api.main.api_endpoint}/api/coincidencias"
    })
  }

  tags = {
    Name     = "${var.proyecto}-bff-service"
    Proyecto = var.proyecto
  }
}

resource "aws_lambda_permission" "apigw_bff" {
  statement_id  = "AllowAPIGatewayInvoke-bff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bff.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ================================================================
# LAMBDA 2: auth-service
# JWT, registro y login de usuarios
# Puerto 8081
# ================================================================

resource "aws_lambda_function" "auth" {
  function_name = "${var.proyecto}-auth-service"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_base}/auth-service:latest"
  timeout       = 30
  memory_size   = 512

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_common_env
  }

  tags = {
    Name     = "${var.proyecto}-auth-service"
    Proyecto = var.proyecto
  }
}

resource "aws_lambda_permission" "apigw_auth" {
  statement_id  = "AllowAPIGatewayInvoke-auth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ================================================================
# LAMBDA 3: ms-mascotas
# CRUD de reportes, upload a S3, publicación en SQS
# Puerto 8082
# ================================================================

resource "aws_lambda_function" "mascotas" {
  function_name = "${var.proyecto}-ms-mascotas"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_base}/ms-mascotas:latest"
  timeout       = 60  # Upload a S3 puede tardar
  memory_size   = 512

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_common_env
  }

  tags = {
    Name     = "${var.proyecto}-ms-mascotas"
    Proyecto = var.proyecto
  }
}

resource "aws_lambda_permission" "apigw_mascotas" {
  statement_id  = "AllowAPIGatewayInvoke-mascotas"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mascotas.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ================================================================
# LAMBDA 4: ms-geolocalizacion
# Geocodificación, clustering DBSCAN
# Modos de invocación:
#   - HTTP (API Gateway): consultas de mapa y heatmap
#   - SQS trigger: procesa ReporteNuevoEvent asíncronamente
# Puerto 8083
# ================================================================

resource "aws_lambda_function" "geo" {
  function_name = "${var.proyecto}-ms-geolocalizacion"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_base}/ms-geolocalizacion:latest"
  timeout       = 120  # Geocoding + clustering puede tardar
  memory_size   = 512

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_common_env
  }

  tags = {
    Name     = "${var.proyecto}-ms-geolocalizacion"
    Proyecto = var.proyecto
  }
}

resource "aws_lambda_permission" "apigw_geo" {
  statement_id  = "AllowAPIGatewayInvoke-geo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# SQS trigger: procesa ReporteNuevoEvent
resource "aws_lambda_event_source_mapping" "sqs_geo" {
  event_source_arn = aws_sqs_queue.reportes_nuevos.arn
  function_name    = aws_lambda_function.geo.arn
  batch_size       = 1  # Procesar un evento a la vez (DBSCAN es costoso)
  enabled          = true
}

# ================================================================
# LAMBDA 5: ms-coincidencias
# Scoring y matching fuzzy de reportes
# Modos de invocación:
#   - HTTP (API Gateway): consulta de coincidencias
#   - SQS trigger: procesa GeoCompletadoEvent asíncronamente
# Puerto 8084
# ================================================================

resource "aws_lambda_function" "coincidencias" {
  function_name = "${var.proyecto}-ms-coincidencias"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_base}/ms-coincidencias:latest"
  timeout       = 120
  memory_size   = 512

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_common_env
  }

  tags = {
    Name     = "${var.proyecto}-ms-coincidencias"
    Proyecto = var.proyecto
  }
}

resource "aws_lambda_permission" "apigw_coincidencias" {
  statement_id  = "AllowAPIGatewayInvoke-coincidencias"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.coincidencias.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# SQS trigger: procesa GeoCompletadoEvent
resource "aws_lambda_event_source_mapping" "sqs_coincidencias" {
  event_source_arn = aws_sqs_queue.geo_completados.arn
  function_name    = aws_lambda_function.coincidencias.arn
  batch_size       = 1
  enabled          = true
}
