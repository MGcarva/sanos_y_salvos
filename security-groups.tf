# ================================================================
# SECURITY GROUPS — Sanos y Salvos (Lambda Architecture)
# Las reglas de ingreso desde Lambda se definen en lambda.tf
# ================================================================

# ================================================================
# RDS POSTGRESQL — Base de datos (puerto 5432)
# Solo accesible desde Lambda
# Las reglas de ingreso se definen en lambda.tf como aws_security_group_rule
# ================================================================

resource "aws_security_group" "rds" {
  name        = "${var.proyecto}-sg-rds"
  description = "Acceso a PostgreSQL desde Lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-rds"
    Proyecto = var.proyecto
  }
}

# ================================================================
# ELASTICACHE REDIS — Cache (puerto 6379)
# auth-service y ms-mascotas lo usan para sesiones
# Las reglas de ingreso se definen en lambda.tf como aws_security_group_rule
# ================================================================

resource "aws_security_group" "redis" {
  name        = "${var.proyecto}-sg-redis"
  description = "Acceso a Redis desde Lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-redis"
    Proyecto = var.proyecto
  }
}
