variable "app_name" {
  description = "Nombre de la app en Amplify"
  type        = string
}

variable "repository" {
  description = "Repositorio de GitHub del frontend"
  type        = string
}

variable "github_access_token" {
  type      = string
  sensitive = true
  default   = null
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_client_id" {
  type = string
}

variable "cognito_domain" {
  description = "Prefijo del dominio del Hosted UI"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "api_base_url" {
  description = "URL base del API Gateway (incluye el stage)"
  type        = string
}
