# ================================================================
# SECRETS MANAGER — Credenciales sensibles centralizadas
# Los contenedores ECS leen estos secretos en tiempo de arranque
# Nunca se pasan como texto plano en variables de entorno
# ================================================================

# ================================================================
# SECRETO: Base de datos (compartido por los 4 microservicios)
# ================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.proyecto}/db-credentials"
  description             = "Credenciales PostgreSQL para los microservicios"
  recovery_window_in_days = 0   # 0 = eliminación inmediata (útil en Academy)

  tags = {
    Proyecto = var.proyecto
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = tostring(aws_db_instance.main.port)
  })
}

# ================================================================
# SECRETO: Redis
# ================================================================

resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "${var.proyecto}/redis-credentials"
  description             = "Credenciales Redis para auth-service y bff-service"
  recovery_window_in_days = 0

  tags = {
    Proyecto = var.proyecto
  }
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id

  secret_string = jsonencode({
    password = var.redis_password
    host     = aws_elasticache_cluster.redis.cache_nodes[0].address
    port     = tostring(aws_elasticache_cluster.redis.cache_nodes[0].port)
  })
}

# ================================================================
# SECRETO: RabbitMQ
# ================================================================

resource "aws_secretsmanager_secret" "rabbitmq_credentials" {
  name                    = "${var.proyecto}/rabbitmq-credentials"
  description             = "Credenciales RabbitMQ para los microservicios"
  recovery_window_in_days = 0

  tags = {
    Proyecto = var.proyecto
  }
}

resource "aws_secretsmanager_secret_version" "rabbitmq_credentials" {
  secret_id = aws_secretsmanager_secret.rabbitmq_credentials.id

  secret_string = jsonencode({
    username = var.rabbitmq_user
    password = var.rabbitmq_password
  })
}

# ================================================================
# SECRETO: JWT Secret
# ================================================================

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.proyecto}/jwt-secret"
  description             = "Clave secreta JWT compartida por todos los microservicios"
  recovery_window_in_days = 0

  tags = {
    Proyecto = var.proyecto
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id

  secret_string = jsonencode({
    secret = var.jwt_secret
  })
}
