output "api_gateway_endpoint" {
  value       = module.api_gateway.endpoint
  description = "URL del api Gateway"
}

output "cognito_user_pool_id" {
  value       = module.cognito.user_pool_id
  description = "ID del user pool de cognito"
}

output "cognito_client_id" {
  value       = module.cognito.client_id
  description = "Client id para el front"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "Nombre del cluster ECS"
}

output "dynamodb_table_name" {
  value       = module.dynamodb.table_name
  description = "Nombre de la tabla DynamoDB"
}

output "dynamodb_table_arn" {
  value       = module.dynamodb.table_arn
  description = "ARN de la tabla DynamoDB"
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "URL del repositorio ECR para push de imágenes"
}

output "rabbitmq_dashboard" {
  value       = "http://${module.rabbitmq.public_ip}:15672"
  description = "Dashboard del nodo 1 (los nodos 2 y 3 en 15673 y 15674)"
}

output "rabbitmq_usuario" {
  value = module.rabbitmq.username
}

output "rabbitmq_password" {
  value     = module.rabbitmq.password
  sensitive = true
}

output "rabbitmq_instance_id" {
  value = module.rabbitmq.instance_id
}

output "ecr_mensajeria_url" {
  value = module.ecr.mensajeria_repository_url
}

output "ecs_mensajeria_service_name" {
  value = module.ecs.mensajeria_service_name
}

output "amplify_url" {
  value       = module.amplify.url
  description = "URL pública del front (va en callback/logout de Cognito)"
}

output "api_gateway_id" {
  value = module.api_gateway.api_id
}

output "api_integration_ids" {
  value = module.api_gateway.integration_ids
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "productos_api_url" {
  value       = module.api_gateway.productos_url
  description = "URL del endpoint de productos"
}

output "api_stage_name" {
  value       = module.api_gateway.stage_name
  description = "Nombre del stage del API Gateway"
}
/*
output "rabbitmq_endpoint" {
  value       = module.rabbitmq.endpoint
  description = "URL de rabbitMQ"
}
*/