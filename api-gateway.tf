# ================================================================
# API GATEWAY — HTTP API (v2)
# Punto de entrada único para todas las peticiones HTTP
# Reemplaza el ALB como router principal de la aplicación
#
# Ventajas sobre ALB:
# - Manejo nativo de Lambda (sin target groups)
# - CORS integrado a nivel de API
# - Menor latencia (no hay backend EC2 que arrancar)
# - Compatible con AWS Academy sin restricciones
#
# Rutas configuradas:
#   ANY /api/auth/{proxy+}          → Lambda: auth-service
#   ANY /api/mascotas/{proxy+}      → Lambda: ms-mascotas
#   ANY /api/geo/{proxy+}           → Lambda: ms-geolocalizacion
#   ANY /api/coincidencias/{proxy+} → Lambda: ms-coincidencias
#   ANY /api/{proxy+}               → Lambda: bff-service (fallback)
# ================================================================

# ================================================================
# API GATEWAY HTTP API
# ================================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.proyecto}-api"
  protocol_type = "HTTP"
  description   = "API Gateway para Sanos y Salvos — enruta hacia Lambdas en VPC"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key"]
    max_age       = 300
  }

  tags = {
    Name     = "${var.proyecto}-api-gateway"
    Proyecto = var.proyecto
  }
}

# ================================================================
# STAGE "$default" — Auto-deploy habilitado
# La URL pública es: https://<id>.execute-api.us-east-1.amazonaws.com
# (sin prefijo de stage, ideal para uso con SPAs)
# ================================================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name     = "${var.proyecto}-stage-default"
    Proyecto = var.proyecto
  }
}

# ================================================================
# INTEGRACIONES Y RUTAS — Una por microservicio
# integration_type = "AWS_PROXY" → Lambda recibe el evento completo
# payload_format_version = "2.0" → compatible con Lambda Web Adapter
# ================================================================

# --- auth-service ---
resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

# --- ms-mascotas ---
resource "aws_apigatewayv2_integration" "mascotas" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.mascotas.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "mascotas" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/mascotas/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.mascotas.id}"
}

# --- ms-geolocalizacion ---
resource "aws_apigatewayv2_integration" "geo" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.geo.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "geo" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/geo/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.geo.id}"
}

# --- ms-coincidencias ---
resource "aws_apigatewayv2_integration" "coincidencias" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.coincidencias.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "coincidencias" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/coincidencias/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.coincidencias.id}"
}

# --- bff-service (fallback — captura /api/* que no coincida con rutas específicas) ---
resource "aws_apigatewayv2_integration" "bff" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.bff.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "bff" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.bff.id}"
}
