# EC2 que ejecuta el docker-compose del clúster de RabbitMQ (3 nodos en contenedores).
# Los 3 nodos comparten máquina: demuestra clúster y replicación, no alta disponibilidad real.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "random_password" "rabbitmq" {
  length  = 24
  special = false
}

resource "random_password" "erlang_cookie" {
  length  = 32
  special = false
}

resource "aws_security_group" "rabbitmq" {
  name        = "${var.project_name}-rabbitmq-sg"
  description = "Cluster RabbitMQ: AMQP solo desde ECS, dashboard solo desde el admin"
  vpc_id      = var.vpc_id

  ingress {
    description     = "AMQP de los 3 nodos desde las tasks de ECS"
    from_port       = 5672
    to_port         = 5674
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  ingress {
    description = "Dashboard de los 3 nodos desde la IP del administrador"
    from_port   = 15672
    to_port     = 15674
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "SSH desde EC2 Instance Connect (consola web, us-east-1)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.206.107.24/29"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "rabbitmq" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.rabbitmq.id]
  associate_public_ip_address = true
  # Perfil del Learner Lab: permite conectarse por Session Manager
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    docker_compose = file(var.docker_compose_path)
    rabbitmq_conf  = file(var.rabbitmq_conf_path)
    usuario        = var.rabbitmq_username
    password       = random_password.rabbitmq.result
    erlang_cookie  = random_password.erlang_cookie.result
  })
  # Si cambia el compose o la configuración, se recrea la máquina con la versión nueva
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-rabbitmq"
  }
}
