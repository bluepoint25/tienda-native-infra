resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Dos integraciones porque la URI es fija: una para la colección y otra para /{id}...
# La IP de la task cambia en cada despliegue: la escribe scripts/publicar-ecs.ps1
resource "aws_apigatewayv2_integration" "productos" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  payload_format_version = "1.0"
  integration_uri        = "${var.backend_url}/api/v1/productos"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

resource "aws_apigatewayv2_integration" "productos_item" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  payload_format_version = "1.0"
  integration_uri        = "${var.backend_url}/api/v1/productos/{proxy}"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

# ms-mensajeria: eventos del panel y administrador de RabbitMQ
resource "aws_apigatewayv2_integration" "mensajeria_eventos" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  payload_format_version = "1.0"
  integration_uri        = "${var.mensajeria_url}/api/v1/eventos"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

resource "aws_apigatewayv2_integration" "mensajeria_admin" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  payload_format_version = "1.0"
  integration_uri        = "${var.mensajeria_url}/api/v1/admin/{proxy}"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

# Valida firma, issuer, audiencia (client_id) y expiración antes de llegar al backend
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  name             = "cognito-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_user_pool_id}"
    audience = [var.cognito_client_id]
  }
}

# La autorización completa del sistema: ruta -> scope exigido
locals {
  rutas_coleccion = {
    "GET /api/v1/productos"  = "productos/read"
    "POST /api/v1/productos" = "productos/write"
  }
  rutas_item = {
    "GET /api/v1/productos/{proxy+}"    = "productos/read"
    "PUT /api/v1/productos/{proxy+}"    = "productos/write"
    "PATCH /api/v1/productos/{proxy+}"  = "productos/write"
    "DELETE /api/v1/productos/{proxy+}" = "productos/write"
  }
}

locals {
  rutas_admin = {
    "GET /api/v1/admin/{proxy+}"    = "productos/read"
    "POST /api/v1/admin/{proxy+}"   = "productos/write"
    "DELETE /api/v1/admin/{proxy+}" = "productos/write"
  }
}

resource "aws_apigatewayv2_route" "eventos" {
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = "GET /api/v1/eventos"
  target               = "integrations/${aws_apigatewayv2_integration.mensajeria_eventos.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["productos/read"]
}

resource "aws_apigatewayv2_route" "admin" {
  for_each             = local.rutas_admin
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.mensajeria_admin.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = [each.value]
}

resource "aws_apigatewayv2_route" "coleccion" {
  for_each             = local.rutas_coleccion
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.productos.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = [each.value]
}

resource "aws_apigatewayv2_route" "item" {
  for_each             = local.rutas_item
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.productos_item.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = [each.value]
}

moved {
  from = aws_apigatewayv2_integration.backend
  to   = aws_apigatewayv2_integration.productos
}
moved {
  from = aws_apigatewayv2_route.productos_get
  to   = aws_apigatewayv2_route.coleccion["GET /api/v1/productos"]
}
moved {
  from = aws_apigatewayv2_route.productos_post
  to   = aws_apigatewayv2_route.coleccion["POST /api/v1/productos"]
}
moved {
  from = aws_apigatewayv2_route.productos_get_id
  to   = aws_apigatewayv2_route.item["GET /api/v1/productos/{proxy+}"]
}
moved {
  from = aws_apigatewayv2_route.productos_put
  to   = aws_apigatewayv2_route.item["PUT /api/v1/productos/{proxy+}"]
}
moved {
  from = aws_apigatewayv2_route.productos_patch
  to   = aws_apigatewayv2_route.item["PATCH /api/v1/productos/{proxy+}"]
}
moved {
  from = aws_apigatewayv2_route.productos_delete
  to   = aws_apigatewayv2_route.item["DELETE /api/v1/productos/{proxy+}"]
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.environment
  auto_deploy = true
}
