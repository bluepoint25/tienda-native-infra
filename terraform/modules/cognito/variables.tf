variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "amplify_domain" {
  description = "Dominio de la app en Amplify (sin https://)"
  type        = string
}

variable "lector_user_email" {
  description = "Email del usuario de solo lectura"
  type        = string
}

variable "lector_user_password" {
  description = "Contraseña temporal del usuario lector (se cambia en el primer login)"
  type        = string
  sensitive   = true
}

variable "test_user_email" {
  description = "Email del usuario de prueba"
  type        = string
  default     = "test@tiendanative.com"
}

variable "test_user_password" {
  description = "Contraseña del usuario de prueba"
  type        = string
  sensitive   = true
}