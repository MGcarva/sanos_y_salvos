# ================================================================
# ECS � Bloqueado en AWS Academy (ecs:CreateCluster, ecs:RegisterTaskDefinition)
# Los task definitions y servicios se crean manualmente desde la consola
# o con aws cli una vez se tenga una cuenta sin restricciones.
# El CloudWatch Log Group se mantiene aqui para recibir logs cuando ECS corra.
# ================================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.proyecto}"
  retention_in_days = 7

  tags = {
    Proyecto = var.proyecto
  }
}
