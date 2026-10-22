output "repository_url" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.backend.repository_url
}

output "mensajeria_repository_url" {
  value = aws_ecr_repository.mensajeria.repository_url
}

output "repository_name" {
  description = "Nombre del repositorio ECR"
  value       = aws_ecr_repository.backend.name
}

output "repository_arn" {
  description = "ARN del repositorio ECR"
  value       = aws_ecr_repository.backend.arn
}
