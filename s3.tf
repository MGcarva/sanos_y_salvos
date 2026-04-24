# ================================================================
# S3 — Almacenamiento de fotos de mascotas
# AWS Academy bloquea GetBucketObjectLockConfiguration por lo que
# el recurso aws_s3_bucket NO puede ser gestionado por Terraform.
# El bucket se crea y configura con AWS CLI (ver comandos al final).
# ================================================================

# Nombre del bucket usado como referencia en iam.tf y ecs.tf
locals {
  s3_bucket_name = "sanos-y-salvos-mascotas-fotos"
  s3_bucket_arn  = "arn:aws:s3:::sanos-y-salvos-mascotas-fotos"
  s3_bucket_url  = "https://sanos-y-salvos-mascotas-fotos.s3.${var.region}.amazonaws.com"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3"
  value       = local.s3_bucket_name
}

output "s3_bucket_url" {
  description = "URL base para acceder a las fotos"
  value       = local.s3_bucket_url
}
