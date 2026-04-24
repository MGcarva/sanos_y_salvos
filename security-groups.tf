# ================================================================
# SECURITY GROUPS — Sanos y Salvos
# Cada grupo controla qué tráfico puede entrar y salir de cada capa
# Principio: mínimo privilegio — solo se abre lo estrictamente necesario
# ================================================================

# ================================================================
# 1. ALB — Application Load Balancer (capa pública)
# Recibe tráfico de internet en puerto 80
# ================================================================

resource "aws_security_group" "alb" {
  name        = "${var.proyecto}-sg-alb"
  description = "Trafico publico hacia el Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Entrada: HTTP desde cualquier IP de internet
  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida: permite redirigir al frontend y al BFF
  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-alb"
    Proyecto = var.proyecto
  }
}

# ================================================================
# 2. FRONTEND — Next.js (puerto 3000)
# Solo recibe tráfico del ALB
# ================================================================

resource "aws_security_group" "frontend" {
  name        = "${var.proyecto}-sg-frontend"
  description = "Trafico hacia el contenedor Frontend desde el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP desde el ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-frontend"
    Proyecto = var.proyecto
  }
}

# ================================================================
# 3. BFF SERVICE — Backend for Frontend (puerto 8080)
# Recibe del ALB, llama a los 4 microservicios internamente
# ================================================================

resource "aws_security_group" "bff" {
  name        = "${var.proyecto}-sg-bff"
  description = "Trafico hacia el BFF Service desde el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP desde el ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-bff"
    Proyecto = var.proyecto
  }
}

# ================================================================
# 4. MICROSERVICIOS — auth, mascotas, geo, coincidencias
# Puertos 8081-8084
# Solo reciben tráfico del BFF (no están expuestos a internet)
# ================================================================

resource "aws_security_group" "microservicios" {
  name        = "${var.proyecto}-sg-microservicios"
  description = "Trafico hacia los microservicios Java desde el BFF"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Microservicios desde el BFF"
    from_port       = 8081
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.bff.id]
  }

  # Los microservicios también se llaman entre sí (ej: coincidencias llama a mascotas vía BFF)
  ingress {
    description     = "Microservicios entre si - comunicacion interna"
    from_port       = 8081
    to_port         = 8084
    protocol        = "tcp"
    self            = true
  }

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-microservicios"
    Proyecto = var.proyecto
  }
}

# ================================================================
# 5. RABBITMQ — Mensajería asíncrona (puertos 5672 y 15672)
# 5672  = AMQP (comunicación entre microservicios)
# 15672 = Management UI (solo desde dentro de la VPC)
# ================================================================

resource "aws_security_group" "rabbitmq" {
  name        = "${var.proyecto}-sg-rabbitmq"
  description = "Trafico AMQP hacia RabbitMQ desde los microservicios"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "AMQP desde microservicios"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.microservicios.id]
  }

  ingress {
    description = "Management UI solo desde dentro de la VPC"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-rabbitmq"
    Proyecto = var.proyecto
  }
}

# ================================================================
# 6. RDS POSTGRESQL — Base de datos (puerto 5432)
# Solo accesible desde los microservicios
# NUNCA expuesto a internet
# ================================================================

resource "aws_security_group" "rds" {
  name        = "${var.proyecto}-sg-rds"
  description = "Acceso a PostgreSQL solo desde los microservicios"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde microservicios"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.microservicios.id]
  }

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
# 7. ELASTICACHE REDIS — Cache (puerto 6379)
# auth-service lo usa para sesiones
# bff-service lo usa para cache de dashboard
# ================================================================

resource "aws_security_group" "redis" {
  name        = "${var.proyecto}-sg-redis"
  description = "Acceso a Redis desde BFF y auth-service"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis desde BFF"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.bff.id]
  }

  ingress {
    description     = "Redis desde microservicios (auth-service)"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.microservicios.id]
  }

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
