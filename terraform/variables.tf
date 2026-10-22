variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Nombre del proyecto"
}
variable "project_name" {
  type        = string
  default     = "tienda-native"
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "ambiente (dev,staging,prod)"


  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El enviroment debe ser dev, staging o prod."
  }
}
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets"
  type        = list(string)
}

variable "docker_image" {
  description = "URL de la imagen Docker"
  type        = string
  default     = "nginx:latest"
}

variable "admin_cidr" {
  description = "IP pública del administrador (/32): única que puede abrir el dashboard de RabbitMQ"
  type        = string
}

variable "amplify_app_id" {
  description = "ID de la app de Amplify creada en la consola (se importa)"
  type        = string
  default     = "d2zvrnvwyv08pa"
}

variable "amplify_app_name" {
  type    = string
  default = "Tienda-native"
}

variable "frontend_repository" {
  type    = string
  default = "https://github.com/bluepoint25/Tienda-native"
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

variable "rabbitmq_password" {
  description = "Contraseña de RabbitMQ"
  type        = string
  sensitive   = true
}
