# ================================================================
# SQS — Amazon Simple Queue Service
# Reemplaza RabbitMQ como bus de mensajería entre microservicios
# SQS es totalmente gestionado por AWS (sin servidor que mantener)
# y es compatible con AWS Academy sin restricciones de IAM adicionales
#
# Flujo de mensajes:
#   ms-mascotas → [reportes-nuevos] → ms-geolocalizacion (Lambda trigger)
#   ms-geolocalizacion → [geo-completados] → ms-coincidencias (Lambda trigger)
#   ms-coincidencias → [notificaciones] → (futuro: servicio de notificaciones)
# ================================================================

# ================================================================
# COLA 1: reportes-nuevos
# ms-mascotas publica aquí cuando se crea un reporte nuevo
# ms-geolocalizacion consume via Lambda SQS trigger
# ================================================================

resource "aws_sqs_queue" "reportes_nuevos" {
  name                       = "${var.proyecto}-reportes-nuevos"
  visibility_timeout_seconds = 300  # Tiempo que tiene Lambda para procesar
  message_retention_seconds  = 86400  # 24 horas de retención
  receive_wait_time_seconds  = 20   # Long polling (reduce costos)

  # Cola de mensajes fallidos (DLQ)
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reportes_nuevos_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name     = "${var.proyecto}-reportes-nuevos"
    Proyecto = var.proyecto
  }
}

resource "aws_sqs_queue" "reportes_nuevos_dlq" {
  name                      = "${var.proyecto}-reportes-nuevos-dlq"
  message_retention_seconds = 604800  # 7 días para inspección de errores
  tags = {
    Name     = "${var.proyecto}-reportes-nuevos-dlq"
    Proyecto = var.proyecto
  }
}

# ================================================================
# COLA 2: geo-completados
# ms-geolocalizacion publica aquí tras geocodificar y clusterizar
# ms-coincidencias consume via Lambda SQS trigger
# ================================================================

resource "aws_sqs_queue" "geo_completados" {
  name                       = "${var.proyecto}-geo-completados"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.geo_completados_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name     = "${var.proyecto}-geo-completados"
    Proyecto = var.proyecto
  }
}

resource "aws_sqs_queue" "geo_completados_dlq" {
  name                      = "${var.proyecto}-geo-completados-dlq"
  message_retention_seconds = 604800
  tags = {
    Name     = "${var.proyecto}-geo-completados-dlq"
    Proyecto = var.proyecto
  }
}

# ================================================================
# COLA 3: notificaciones
# ms-coincidencias publica aquí cuando encuentra una coincidencia
# (Futuro: Lambda de notificaciones vía email/push)
# ================================================================

resource "aws_sqs_queue" "notificaciones" {
  name                       = "${var.proyecto}-notificaciones"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = {
    Name     = "${var.proyecto}-notificaciones"
    Proyecto = var.proyecto
  }
}

# ================================================================
# POLÍTICA DE ACCESO SQS
# Permite que las Lambdas y los microservicios accedan a las colas
# La LabRole ya tiene permisos SQS en AWS Academy
# ================================================================

resource "aws_sqs_queue_policy" "reportes_nuevos" {
  queue_url = aws_sqs_queue.reportes_nuevos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_iam_role.lab_role.arn }
      Action    = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource  = aws_sqs_queue.reportes_nuevos.arn
    }]
  })
}

resource "aws_sqs_queue_policy" "geo_completados" {
  queue_url = aws_sqs_queue.geo_completados.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_iam_role.lab_role.arn }
      Action    = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource  = aws_sqs_queue.geo_completados.arn
    }]
  })
}
