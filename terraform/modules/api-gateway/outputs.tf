output "api_id" {
  description = "ID del API Gateway"
  value       = aws_apigatewayv2_api.api.id
}

output "integration_ids" {
  description = "Integraciones que reapunta el script de despliegue"
  value = {
    productos          = aws_apigatewayv2_integration.productos.id
    productos_item     = aws_apigatewayv2_integration.productos_item.id
    mensajeria_eventos = aws_apigatewayv2_integration.mensajeria_eventos.id
    mensajeria_admin   = aws_apigatewayv2_integration.mensajeria_admin.id
  }
}

output "endpoint" {
  description = "URL del API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "productos_url" {
  description = "URL para acceder a productos"
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}/api/v1/productos"
}

output "productos_base_url" {
  description = "Base que usa el front (VITE_API_BASE_URL): endpoint + stage"
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
}

output "stage_name" {
  description = "Nombre del stage"
  value       = aws_apigatewayv2_stage.prod.name
}