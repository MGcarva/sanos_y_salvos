# ================================================================
# EC2 — Backend Server (reemplaza ECS que está bloqueado en Academy)
# Una sola instancia t3.medium corre todos los microservicios Docker
# ================================================================

# Obtener el Account ID actual (necesario para URLs de ECR y S3)
data "aws_caller_identity" "current" {}

# Última AMI de Amazon Linux 2023 (x86_64)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ================================================================
# SECURITY GROUP EC2
# Permite tráfico del ALB (8080) + SSH (22) + acceso directo debug
# Las reglas de RDS y Redis se agregan abajo con sg_rule
# ================================================================

resource "aws_security_group" "ec2" {
  name        = "${var.proyecto}-sg-ec2"
  description = "EC2 backend: puertos de aplicacion y SSH para debug"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH para debug durante presentacion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "BFF desde ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Microservicios acceso directo para debug"
    from_port   = 8081
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida sin restricciones"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.proyecto}-sg-ec2"
    Proyecto = var.proyecto
  }
}

# ================================================================
# REGLAS ADICIONALES — EC2 puede alcanzar RDS y Redis
# Se agregan aquí para evitar ciclos de dependencia en security-groups.tf
# ================================================================

resource "aws_security_group_rule" "rds_desde_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.ec2.id
  description              = "PostgreSQL desde EC2 backend"
}

resource "aws_security_group_rule" "redis_desde_ec2" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.ec2.id
  description              = "Redis desde EC2 backend"
}

# ================================================================
# INSTANCIA EC2 BACKEND
# t3.medium = 2 vCPU + 4GB RAM (necesario para 5 JVMs + RabbitMQ)
# Subnet pública → IP pública para ECR pull y S3 access
# user-data.sh se inyecta con variables dinámicas via templatefile
# ================================================================

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.publica_az_a.id
  associate_public_ip_address = true
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    ecr_registry  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
    proyecto      = var.proyecto
    db_host       = aws_db_instance.main.address
    db_user       = var.db_username
    db_pass       = var.db_password
    redis_host    = aws_elasticache_cluster.redis.cache_nodes[0].address
    redis_pass    = var.redis_password
    rabbitmq_user = var.rabbitmq_user
    rabbitmq_pass = var.rabbitmq_password
    jwt_secret    = var.jwt_secret
    s3_bucket     = local.s3_bucket_name
    aws_region    = var.region
  })

  depends_on = [
    aws_db_instance.main,
    aws_elasticache_cluster.redis,
  ]

  tags = {
    Name     = "${var.proyecto}-backend-ec2"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

# ================================================================
# REGISTRO EN ALB TARGET GROUP
# target_type = "instance" → registrar por ID (no por IP)
# El ALB enruta /api/* al puerto 8080 (bff-service)
# ================================================================

resource "aws_lb_target_group_attachment" "bff" {
  target_group_arn = aws_lb_target_group.bff.arn
  target_id        = aws_instance.backend.id
  port             = 8080
}
