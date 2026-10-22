data "aws_caller_identity" "current" {}

locals {
  lab_role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  # Variables comunes de ambos microservicios: identidad (JWT) y conexión al clúster de RabbitMQ
  entorno_comun = [
    { name = "COGNITO_USER_POOL_ID", value = var.cognito_user_pool_id },
    { name = "AWS_REGION", value = "us-east-1" },
    { name = "RABBITMQ_ADDRESSES", value = var.rabbitmq_addresses },
    { name = "RABBITMQ_USER", value = var.rabbitmq_username },
    { name = "RABBITMQ_PASSWORD", value = var.rabbitmq_password },
  ]
}

# Cluster ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ===== ms-productos (CRUD + DynamoDB + productor) =====

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = local.lab_role
  # Rol con el que el CÓDIGO del contenedor llama a DynamoDB (el de ejecución solo baja la imagen y escribe logs)
  task_role_arn = local.lab_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name         = "${var.project_name}-backend"
      image        = var.docker_image
      essential    = true
      portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
      environment  = local.entorno_comun

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 7
}

resource "aws_ecs_service" "app" {
  name                  = "${var.project_name}-service"
  cluster               = aws_ecs_cluster.main.id
  task_definition       = aws_ecs_task_definition.app.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  force_new_deployment  = false
  wait_for_steady_state = false

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  # Permite que el script de despliegue actualice la imagen sin que Terraform la revierta
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ===== ms-mensajeria (consumidores, DLQ y administrador de RabbitMQ) =====

resource "aws_ecs_task_definition" "mensajeria" {
  family                   = "${var.project_name}-mensajeria-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = local.lab_role
  task_role_arn            = local.lab_role

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name         = "${var.project_name}-mensajeria"
      image        = var.mensajeria_image
      essential    = true
      portMappings = [{ containerPort = 8081, hostPort = 8081, protocol = "tcp" }]
      environment  = local.entorno_comun

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.mensajeria.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "mensajeria" {
  name              = "/ecs/${var.project_name}-mensajeria"
  retention_in_days = 7
}

resource "aws_ecs_service" "mensajeria" {
  name                  = "${var.project_name}-mensajeria-service"
  cluster               = aws_ecs_cluster.main.id
  task_definition       = aws_ecs_task_definition.mensajeria.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  force_new_deployment  = false
  wait_for_steady_state = false

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# Security group compartido por las tasks de ambos microservicios.
# Sin balanceador, quien llama es el API Gateway por internet: la puerta real es el gateway (JWT).
resource "aws_security_group" "app" {
  name        = "${var.project_name}-ecs-sg"
  description = "Security group para ECS"
  vpc_id      = var.vpc_id

  ingress {
    description = "ms-productos"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ms-mensajeria"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
