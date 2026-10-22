output "private_ip" {
  description = "IP privada: no cambia al apagar/encender la EC2, la usan las tasks de ECS"
  value       = aws_instance.rabbitmq.private_ip
}

output "public_ip" {
  description = "IP pública para el dashboard (cambia en cada encendido)"
  value       = aws_instance.rabbitmq.public_ip
}

output "addresses" {
  description = "Valor de RABBITMQ_ADDRESSES para los microservicios"
  value       = join(",", [for p in [5672, 5673, 5674] : "${aws_instance.rabbitmq.private_ip}:${p}"])
}

output "username" {
  value = var.rabbitmq_username
}

output "password" {
  value     = random_password.rabbitmq.result
  sensitive = true
}

output "instance_id" {
  value = aws_instance.rabbitmq.id
}
