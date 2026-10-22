variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito"
  type        = string
}

variable "docker_image" {
  description = "Imagen de ms-productos"
  type        = string
}

variable "mensajeria_image" {
  description = "Imagen de ms-mensajeria"
  type        = string
}

variable "rabbitmq_addresses" {
  description = "host:puerto de los nodos del clúster, separados por coma"
  type        = string
}

variable "rabbitmq_username" {
  type = string
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}

variable "cors_allowed_origins" {
  description = "Orígenes permitidos por los microservicios, separados por coma"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID donde correr ECS"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets"
  type        = list(string)
}
