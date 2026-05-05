# ================================================================
# OUTPUTS — Valores útiles tras el despliegue
# ================================================================

output "s3_bucket_frontend" {
  description = "Bucket S3 para fotos de mascotas"
  value       = local.s3_bucket_name
}

output "s3_bucket_fotos" {
  description = "Bucket S3 para fotos de mascotas"
  value       = local.s3_bucket_url
}

output "sqs_reportes_nuevos_url" {
  description = "URL de la cola SQS reportes-nuevos"
  value       = aws_sqs_queue.reportes_nuevos.url
}

output "sqs_geo_completados_url" {
  description = "URL de la cola SQS geo-completados"
  value       = aws_sqs_queue.geo_completados.url
}

output "sqs_notificaciones_url" {
  description = "URL de la cola SQS notificaciones"
  value       = aws_sqs_queue.notificaciones.url
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "resumen_despliegue" {
  description = "Resumen completo del despliegue"
  value = {
    arquitectura = "Lambda + API Gateway + RDS + ElastiCache + SQS"
    api_url      = aws_apigatewayv2_stage.default.invoke_url
    rds = {
      host   = aws_db_instance.main.address
      port   = aws_db_instance.main.port
      engine = "PostgreSQL 15"
    }
    redis = {
      host = aws_elasticache_cluster.redis.cache_nodes[0].address
      port = aws_elasticache_cluster.redis.cache_nodes[0].port
    }
    sqs_queues = 3
  }
}
