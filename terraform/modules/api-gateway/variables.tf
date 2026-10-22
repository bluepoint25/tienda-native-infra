variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}
variable "cognito_user_pool_id" {
  description = "User pool que emite los tokens (issuer)"
  type        = string
}

variable "cognito_client_id" {
  description = "App client cuyos tokens se aceptan (audience)"
  type        = string
}

variable "mensajeria_url" {
  description = "URL inicial de ms-mensajeria (la IP real la escribe el script de despliegue)"
  type        = string
}

variable "backend_url" {
  description = "URL del backend en ECS"
  type        = string
}