# ================================================================
# ELASTICACHE REDIS 7
# Usado por auth-service (sesiones/tokens) y bff-service (cache dashboard)
# ================================================================

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.proyecto}-redis-subnet-group-new"
  description = "Subnet group para Redis en 2 AZs"
  subnet_ids  = [
    aws_subnet.privada_az_a.id,
    aws_subnet.privada_az_b.id
  ]

  tags = {
    Name     = "${var.proyecto}-redis-subnet-group"
    Proyecto = var.proyecto
  }

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

# import {
#   to = aws_elasticache_subnet_group.main
#   id = "sanos-y-salvos-redis-subnet-group-v2"
# }

# import {
#   to = aws_elasticache_cluster.redis
#   id = "sanos-y-salvos-redis-v2"
# }

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.proyecto}-redis-new"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type   # cache.t3.micro
  num_cache_nodes      = 1                     # 1 nodo — suficiente para Academy
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # AWS Academy no soporta transit_encryption en aws_elasticache_cluster
  # Sin mantenimiento agresivo en Academy
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_retention_limit = 0   # Sin snapshots para no gastar almacenamiento

  tags = {
    Name     = "${var.proyecto}-redis"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

output "redis_endpoint" {
  description = "Endpoint de Redis — se usa como REDIS_HOST en variables de entorno ECS"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Puerto de Redis"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}
