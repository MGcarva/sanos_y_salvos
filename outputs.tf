# ================================================================
# OUTPUTS — Valores importantes después del terraform apply
# Estos son los datos que necesitas para conectarte al sistema
# y para configurar el CI/CD en GitHub Actions
# ================================================================

output "url_aplicacion" {
  description = "URL pública de la aplicación — abre esto en el navegador"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns" {
  description = "DNS del Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_host" {
  description = "Host de PostgreSQL — usar como DB_HOST en variables de entorno"
  value       = aws_db_instance.main.address
  sensitive   = false
}

output "redis_host" {
  description = "Host de Redis — usar como REDIS_HOST en variables de entorno"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  sensitive   = false
}

output "s3_bucket" {
  description = "Nombre del bucket S3 para fotos de mascotas"
  value       = local.s3_bucket_name
}

output "ecr_login_command" {
  description = "Comando para hacer login a ECR antes de hacer docker push"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.servicios["auth-service"].registry_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "docker_push_commands" {
  description = "Comandos para subir las imagenes a ECR (reemplaza <TAG> por la version)"
  value = {
    for nombre, repo in aws_ecr_repository.servicios :
    nombre => "docker push ${repo.repository_url}:latest"
  }
}

output "resumen_infraestructura" {
  description = "Resumen de todos los recursos creados"
  value = {
    vpc_id          = aws_vpc.main.id
    url             = "http://${aws_lb.main.dns_name}"
    rds_endpoint    = aws_db_instance.main.address
    redis_endpoint  = aws_elasticache_cluster.redis.cache_nodes[0].address
    s3_bucket       = local.s3_bucket_name
    ecr_registry    = "${aws_ecr_repository.servicios["auth-service"].registry_id}.dkr.ecr.${var.region}.amazonaws.com"
  }
}

# ================================================================
# OUTPUTS PARA DEPLOY SCRIPTS
# ================================================================

output "subnet_privada_az_a_id" {
  description = "ID de la subnet privada AZ-a — usada por ECS Fargate"
  value       = aws_subnet.privada_az_a.id
}

output "subnet_privada_az_b_id" {
  description = "ID de la subnet privada AZ-b — usada por ECS Fargate"
  value       = aws_subnet.privada_az_b.id
}

output "sg_frontend_id" {
  description = "Security group del contenedor frontend"
  value       = aws_security_group.frontend.id
}

output "sg_bff_id" {
  description = "Security group del contenedor BFF"
  value       = aws_security_group.bff.id
}

output "sg_microservicios_id" {
  description = "Security group de los microservicios"
  value       = aws_security_group.microservicios.id
}

output "tg_frontend_arn" {
  description = "ARN del target group del frontend — necesario para el servicio ECS"
  value       = aws_lb_target_group.frontend.arn
}

output "tg_bff_arn" {
  description = "ARN del target group del BFF"
  value       = aws_lb_target_group.bff.arn
}

output "lab_role_arn" {
  description = "ARN del LabRole — se usa como execution role y task role en ECS"
  value       = data.aws_iam_role.lab_role.arn
}

output "ecr_frontend_url" {
  description = "URL del repositorio ECR del frontend"
  value       = aws_ecr_repository.servicios["frontend"].repository_url
}

output "ec2_public_ip" {
  description = "IP publica del EC2 backend"
  value       = aws_instance.backend.public_ip
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 backend"
  value       = aws_instance.backend.id
}

# ================================================================
# OUTPUTS NUEVA ARQUITECTURA — Lambda + SQS + API Gateway
# ================================================================

output "api_gateway_url" {
  description = "URL pública del API Gateway — punto de entrada de la nueva arquitectura Lambda"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_id" {
  description = "ID del API Gateway HTTP API"
  value       = aws_apigatewayv2_api.main.id
}

output "sqs_reportes_nuevos_url" {
  description = "URL de la cola SQS reportes-nuevos — configurar como SQS_REPORTES_NUEVOS_URL"
  value       = aws_sqs_queue.reportes_nuevos.url
}

output "sqs_geo_completados_url" {
  description = "URL de la cola SQS geo-completados — configurar como SQS_GEO_COMPLETADOS_URL"
  value       = aws_sqs_queue.geo_completados.url
}

output "sqs_notificaciones_url" {
  description = "URL de la cola SQS notificaciones"
  value       = aws_sqs_queue.notificaciones.url
}

output "lambda_functions" {
  description = "ARNs de las funciones Lambda desplegadas"
  value = {
    bff           = aws_lambda_function.bff.arn
    auth          = aws_lambda_function.auth.arn
    mascotas      = aws_lambda_function.mascotas.arn
    geolocalizacion = aws_lambda_function.geo.arn
    coincidencias = aws_lambda_function.coincidencias.arn
  }
}

output "resumen_nueva_arquitectura" {
  description = "Resumen de la arquitectura Lambda + SQS + API Gateway"
  value = {
    api_gateway_url        = aws_apigatewayv2_api.main.api_endpoint
    sqs_reportes_nuevos    = aws_sqs_queue.reportes_nuevos.url
    sqs_geo_completados    = aws_sqs_queue.geo_completados.url
    endpoints = {
      auth          = "${aws_apigatewayv2_api.main.api_endpoint}/api/auth"
      mascotas      = "${aws_apigatewayv2_api.main.api_endpoint}/api/mascotas"
      geo           = "${aws_apigatewayv2_api.main.api_endpoint}/api/geo"
      coincidencias = "${aws_apigatewayv2_api.main.api_endpoint}/api/coincidencias"
      bff           = "${aws_apigatewayv2_api.main.api_endpoint}/api"
    }
  }
}
