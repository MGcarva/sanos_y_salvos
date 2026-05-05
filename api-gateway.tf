# ================================================================
# API GATEWAY HTTP API v2 — Punto de entrada único
# Expone las Lambda functions vía HTTP
# Más barato y simple que REST API (no tiene AZ cost)
# ================================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.proyecto}-api"
  protocol_type = "HTTP"

  tags = {
    Name     = "${var.proyecto}-api"
    Proyecto = var.proyecto
  }
}

# ================================================================
# INTEGRACIONES — Conecta rutas con Lambda functions
# ================================================================

data "aws_caller_identity" "current" {}

resource "aws_apigatewayv2_integration" "auth" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.proyecto}-auth-service/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "bff" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.proyecto}-bff-service/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "mascotas" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.proyecto}-ms-mascotas/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "geo" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.proyecto}-ms-geolocalizacion/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "coincidencias" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.proyecto}-ms-coincidencias/invocations"
  payload_format_version = "2.0"
}

# ================================================================
# RUTAS — Mapeo de URLs a servicios
# ================================================================

resource "aws_apigatewayv2_route" "auth" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "mascotas" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/mascotas/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.mascotas.id}"
}

resource "aws_apigatewayv2_route" "geo" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/geo/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.geo.id}"
}

resource "aws_apigatewayv2_route" "coincidencias" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/coincidencias/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.coincidencias.id}"
}

resource "aws_apigatewayv2_route" "bff" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.bff.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.bff.id}"
}

# ================================================================
# PERMISOS — API Gateway puede invocar las Lambdas
# ================================================================

# Lambdas y permisos comentados - activar después de subir imágenes
resource "aws_lambda_permission" "auth" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.proyecto}-auth-service"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

resource "aws_lambda_permission" "bff" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.proyecto}-bff-service"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

resource "aws_lambda_permission" "mascotas" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.proyecto}-ms-mascotas"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

resource "aws_lambda_permission" "geo" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.proyecto}-ms-geolocalizacion"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

resource "aws_lambda_permission" "coincidencias" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.proyecto}-ms-coincidencias"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

# ================================================================
# STAGE — Despliegue automático ($default)
# ================================================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name     = "${var.proyecto}-stage"
    Proyecto = var.proyecto
  }
}

# ================================================================
# OUTPUT — URL pública de la API
# ================================================================

output "api_endpoint" {
  description = "URL pública de la API (HTTP API)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_endpoints_map" {
  description = "Endpoints individuales por servicio"
  value = {
    auth          = "${aws_apigatewayv2_stage.default.invoke_url}/api/auth"
    mascotas      = "${aws_apigatewayv2_stage.default.invoke_url}/api/mascotas"
    geo           = "${aws_apigatewayv2_stage.default.invoke_url}/api/geo"
    coincidencias = "${aws_apigatewayv2_stage.default.invoke_url}/api/coincidencias"
    bff           = "${aws_apigatewayv2_stage.default.invoke_url}/api"
  }
}
