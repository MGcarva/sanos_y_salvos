# ================================================================
# ECR — Elastic Container Registry
# Un repositorio por cada microservicio/contenedor
# ECS descarga las imágenes desde aquí para arrancar los contenedores
#
# Flujo: tu máquina → docker build → docker push → ECR → ECS
# ================================================================

locals {
  # Lista de los 5 servicios — se usa para crear los repositorios en bucle
  servicios = [
    "auth-service",
    "ms-mascotas",
    "ms-geolocalizacion",
    "ms-coincidencias",
    "bff-service"
  ]
}

resource "aws_ecr_repository" "servicios" {
  for_each = toset(local.servicios)

  name                 = "${var.proyecto}/${each.key}"
  image_tag_mutability = "MUTABLE"   # Permite sobreescribir el tag "latest"

  # Escaneo automático de vulnerabilidades al hacer push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cifrado de imágenes en reposo usando la clave por defecto de AWS
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name     = "${var.proyecto}-${each.key}"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

import {
  to = aws_ecr_repository.servicios["auth-service"]
  id = "sanos-y-salvos/auth-service"
}

import {
  to = aws_ecr_repository.servicios["bff-service"]
  id = "sanos-y-salvos/bff-service"
}

import {
  to = aws_ecr_repository.servicios["ms-mascotas"]
  id = "sanos-y-salvos/ms-mascotas"
}

import {
  to = aws_ecr_repository.servicios["ms-geolocalizacion"]
  id = "sanos-y-salvos/ms-geolocalizacion"
}

import {
  to = aws_ecr_repository.servicios["ms-coincidencias"]
  id = "sanos-y-salvos/ms-coincidencias"
}

# ================================================================
# POLÍTICA DE CICLO DE VIDA
# Mantiene solo las últimas 5 imágenes por repositorio
# Evita que ECR acumule imágenes viejas y consuma almacenamiento
# ================================================================

resource "aws_ecr_lifecycle_policy" "servicios" {
  for_each   = aws_ecr_repository.servicios
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener solo las ultimas 5 imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ================================================================
# OUTPUTS LOCALES — URLs de ECR por servicio
# Se usan en ecs.tf para armar la URL completa de cada imagen
#
# Formato: 123456789.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/auth-service
# ================================================================

output "ecr_urls" {
  description = "URLs de los repositorios ECR — necesarias para docker push y ECS"
  value = {
    for nombre, repo in aws_ecr_repository.servicios :
    nombre => repo.repository_url
  }
}

output "ecr_registry" {
  description = "URL base del registry ECR de tu cuenta — usa esto en docker login"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}
