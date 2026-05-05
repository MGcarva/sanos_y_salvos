# ================================================================
# LAMBDA — Funciones serverless para microservicios
# ================================================================

locals {
  lambda_services = {
    "auth-service" = {
      port    = 8081
      db_name = "auth_db"
    }
    "ms-mascotas" = {
      port    = 8082
      db_name = "mascotas_db"
    }
    "ms-geolocalizacion" = {
      port    = 8083
      db_name = "geolocalizacion_db"
    }
    "ms-coincidencias" = {
      port    = 8084
      db_name = "coincidencias_db"
    }
    "bff-service" = {
      port    = 8080
      db_name = ""
    }
  }
}

# ================================================================
# SECURITY GROUP PARA LAMBDA
# ================================================================

resource "aws_security_group" "lambda" {
  name        = "${var.proyecto}-sg-lambda"
  description = "Permite que Lambda acceda a RDS y Redis"
  vpc_id      = aws_vpc.main.id

  # Salida para conectarse a la DB
  egress {
    description = "Salida a RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  # Salida para conectarse a Redis
  egress {
    description = "Salida a Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [aws_security_group.redis.id]
  }

  # Salida general para servicios de AWS (SQS, ECR, CloudWatch)
  egress {
    description = "Salida a internet y servicios AWS"
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

# Reglas de entrada cruzadas (Crucial para la conectividad)
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
}

resource "aws_security_group_rule" "redis_from_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.lambda.id
}

# ================================================================
# LAMBDA FUNCTIONS
# ================================================================

resource "aws_lambda_function" "services" {
  for_each = local.lambda_services

  function_name = "${var.proyecto}-${each.key}"
  role          = data.aws_iam_role.lab_role.arn
  package_type  = "Image"
  
  # !!! IMPORTANTE: Esto debe coincidir con el build de Docker !!!
  architectures = ["x86_64"] 
  
  image_uri     = "${aws_ecr_repository.servicios[each.key].repository_url}:latest"

  timeout     = 30
  memory_size = 512

  vpc_config {
    subnet_ids         = [aws_subnet.privada_az_a.id, aws_subnet.privada_az_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = "prod"
      DB_HOST               = aws_db_instance.main.address
      DB_PORT               = "5432"
      DB_NAME               = each.value.db_name
      DB_USERNAME           = var.db_username
      DB_PASSWORD           = var.db_password
      REDIS_HOST            = aws_elasticache_cluster.redis.cache_nodes[0].address
      REDIS_PORT            = "6379"
      REDIS_PASSWORD        = var.redis_password
      JWT_SECRET            = var.jwt_secret
      SQS_REPORTES_NUEVOS   = aws_sqs_queue.reportes_nuevos.url
      SQS_GEO_COMPLETADOS   = aws_sqs_queue.geo_completados.url
      SQS_NOTIFICACIONES    = aws_sqs_queue.notificaciones.url
      # Puerto que escucha el Web Adapter internamente
      PORT                  = each.value.port
    }
  }

  tags = {
    Name     = "${var.proyecto}-${each.key}"
    Proyecto = var.proyecto
  }

  # Asegura que ECR exista antes de intentar crear la Lambda
  depends_on = [aws_ecr_repository.servicios]
}

# ================================================================
# SQS EVENT SOURCE MAPPINGS
# ================================================================

resource "aws_lambda_event_source_mapping" "reportes_nuevos" {
  event_source_arn = aws_sqs_queue.reportes_nuevos.arn
  function_name    = aws_lambda_function.services["ms-geolocalizacion"].function_name
  batch_size       = 1
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "geo_completados" {
  event_source_arn = aws_sqs_queue.geo_completados.arn
  function_name    = aws_lambda_function.services["ms-coincidencias"].function_name
  batch_size       = 1
  enabled          = true
}