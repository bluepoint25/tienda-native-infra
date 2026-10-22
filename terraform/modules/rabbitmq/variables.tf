variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Subred pública donde vive la EC2"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group de las tasks de ECS: las únicas que pueden hablar AMQP"
  type        = string
}

variable "admin_cidr" {
  description = "IP pública (/32) desde la que se abre el dashboard"
  type        = string
}

variable "instance_type" {
  description = "4 GB de RAM alcanzan para 3 nodos de RabbitMQ"
  type        = string
  default     = "t3.medium"
}

variable "rabbitmq_username" {
  type    = string
  default = "admin"
}

variable "docker_compose_path" {
  description = "docker-compose.yml del clúster (el mismo que se usa en local)"
  type        = string
}

variable "rabbitmq_conf_path" {
  type = string
}
