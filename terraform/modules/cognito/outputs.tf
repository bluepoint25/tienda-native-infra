output "user_pool_id" {
  description = "ID del User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "client_id" {
  description = "Client ID para el frontend"
  value       = aws_cognito_user_pool_client.app.id
}

output "user_pool_arn" {
  description = "ARN del User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "domain_name" {
  description = "Dominio de Cognito"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_endpoint" {
  description = "Endpoint para login"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com"
}

output "test_user_username" {
  description = "Usuario de prueba"
  value       = aws_cognito_user.test_user.username
}

output "test_user_email" {
  description = "Email del usuario de prueba"
  value       = var.test_user_email
}

output "test_user_password" {
  description = "Contraseña del usuario de prueba"
  value       = var.test_user_password
  sensitive   = true
}