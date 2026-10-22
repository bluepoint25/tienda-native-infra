terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}


#Modulo Cognito
module "cognito" {
  source = "./modules/cognito"

  project_name         = var.project_name
  environment          = var.environment
  lector_user_email    = var.lector_user_email
  lector_user_password = var.lector_user_password
  test_user_password   = var.test_user_password
  # Cerrar el círculo: la URL que asigna Amplify entra en callback/logout de Cognito
  amplify_domain = "main.${module.amplify.default_domain}"
}

#Modulo Amplify (front conectado al repositorio de GitHub: compila en cada push)
module "amplify" {
  source = "./modules/amplify"

  app_name             = var.amplify_app_name
  repository           = var.frontend_repository
  github_access_token  = var.github_access_token
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id
  cognito_domain       = module.cognito.domain_name
  aws_region           = var.aws_region
  api_base_url         = module.api_gateway.productos_base_url
}

#Modulo DynamoDB
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

#Modulo ECR
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

#Modulo : ECS(back end)
module "ecs" {
  source = "./modules/ecs"

  project_name         = var.project_name
  environment          = var.environment
  cognito_user_pool_id = module.cognito.user_pool_id
  vpc_id               = var.vpc_id
  subnet_ids           = var.subnet_ids
  docker_image         = "${module.ecr.repository_url}:latest"
  mensajeria_image     = "${module.ecr.mensajeria_repository_url}:latest"
  rabbitmq_addresses   = module.rabbitmq.addresses
  rabbitmq_username    = module.rabbitmq.username
  rabbitmq_password    = module.rabbitmq.password
  cors_allowed_origins = "http://localhost:5173,${module.amplify.url}"
}

# No todas las zonas ofrecen t3.medium (ej. us-east-1e): se usa la primera subred cuya zona sí lo ofrece
data "aws_ec2_instance_type_offerings" "rabbitmq" {
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = ["t3.medium"]
  }
}

data "aws_subnet" "candidatas" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

locals {
  subnet_rabbitmq = [
    for s in data.aws_subnet.candidatas : s.id
    if contains(data.aws_ec2_instance_type_offerings.rabbitmq.locations, s.availability_zone)
  ][0]
}

#Modulo RabbitMQ: EC2 que ejecuta el docker-compose del clúster (el mismo archivo que se usa en local)
module "rabbitmq" {
  source = "./modules/rabbitmq"

  project_name          = var.project_name
  vpc_id                = var.vpc_id
  subnet_id             = local.subnet_rabbitmq
  ecs_security_group_id = module.ecs.security_group_id
  admin_cidr            = var.admin_cidr
  docker_compose_path   = "${path.root}/../ms-mensajeria/rabbitmq-cluster/docker-compose.yml"
  rabbitmq_conf_path    = "${path.root}/../ms-mensajeria/rabbitmq-cluster/rabbitmq.conf"
}

#Modulo api Gateway
module "api_gateway" {
  source = "./modules/api-gateway"

  project_name         = var.project_name
  environment          = var.environment
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id
  # Valores iniciales: la IP real de cada task la escribe scripts/publicar-ecs.ps1 (ignore_changes)
  backend_url    = "http://52.0.0.1:8080"
  mensajeria_url = "http://52.0.0.1:8081"
}