variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Región de AWS (el Learner Lab trabaja en us-east-1)"
}

variable "project_name" {
  type        = string
  default     = "tienda-native"
  description = "Prefijo de los nombres de todos los recursos"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Ambiente (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El environment debe ser dev, staging o prod."
  }
}

variable "vpc_id" {
  description = "VPC por defecto del lab"
  type        = string
}

variable "subnet_ids" {
  description = "Subredes públicas de esa VPC (al menos una en una zona que ofrezca t3.medium)"
  type        = list(string)
}

variable "admin_cidr" {
  description = "IP pública del administrador (/32): única que puede abrir el dashboard de RabbitMQ"
  type        = string
}

variable "amplify_app_name" {
  type    = string
  default = "Tienda-native"
}

variable "frontend_repository" {
  description = "Repositorio de GitHub del frontend (un fork propio si se reproduce en otra cuenta)"
  type        = string
  default     = "https://github.com/bluepoint25/Tienda-native"
}

variable "github_access_token" {
  description = "Token de GitHub (permiso repo) para que Amplify se conecte al repositorio al crear la app"
  type        = string
  sensitive   = true
  default     = null
}

variable "lector_user_email" {
  description = "Email del usuario de solo lectura"
  type        = string
  default     = "lector@tiendanative.com"
}

variable "test_user_password" {
  description = "Contraseña temporal del usuario editor de prueba"
  type        = string
  sensitive   = true
}

variable "lector_user_password" {
  description = "Contraseña temporal del usuario lector"
  type        = string
  sensitive   = true
}
