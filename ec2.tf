# ================================================================
# EC2 — Instancia backend (Docker host)
# Ejecuta todos los microservicios como contenedores Docker.
# AWS Academy bloquea ECS, por eso usamos EC2 directamente.
# ================================================================

resource "aws_instance" "backend" {
  ami                         = "ami-0102a36b3e9d5e4df"   # Amazon Linux 2023 us-east-1
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.publica_az_a.id
  associate_public_ip_address = true
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = "${var.proyecto}-backend-key"

  vpc_security_group_ids = [
    aws_security_group.bff.id,
    aws_security_group.microservicios.id,
    aws_security_group.frontend.id,
  ]

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name     = "${var.proyecto}-backend"
    Proyecto = var.proyecto
  }

  # Ignora cambios en user_data para no re-crear la instancia en cada apply
  lifecycle {
    ignore_changes = [user_data]
  }
}

# ================================================================
# REGISTRO EN TARGET GROUPS — conecta el EC2 al ALB
# target_type = "ip" requiere registrar la IP privada de la instancia
# ================================================================

resource "aws_lb_target_group_attachment" "bff" {
  target_group_arn = aws_lb_target_group.bff.arn
  target_id        = aws_instance.backend.private_ip
  port             = 8080
}

# Frontend servido desde S3 (ver deploy-frontend.ps1)
# El ALB redirige / → S3 bucket, no necesita target en EC2
