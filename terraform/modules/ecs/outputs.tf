output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.app.name
}

output "mensajeria_service_name" {
  value = aws_ecs_service.mensajeria.name
}

output "security_group_id" {
  description = "SG de las tasks: el clúster de RabbitMQ solo acepta AMQP desde aquí"
  value       = aws_security_group.app.id
}

output "task_definition_arn" {
  description = "ARN de la Task Definition"
  value       = aws_ecs_task_definition.app.arn
}