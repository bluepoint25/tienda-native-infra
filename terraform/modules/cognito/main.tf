data "aws_caller_identity" "current" {}

# User pool donde se guardan los usuarios
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # Pre Token Generation V2 (scopes en el access token) solo existe desde ESSENTIALS
  user_pool_tier = "ESSENTIALS"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.user_token_ms.arn
      lambda_version = "V2_0"
    }
  }
}

# Declara que los scopes existen; NO se conceden en el cliente, los agrega el Lambda por grupo
resource "aws_cognito_resource_server" "productos" {
  identifier   = "productos"
  name         = "API de productos"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "read"
    scope_description = "Consultar productos"
  }
  scope {
    scope_name        = "write"
    scope_description = "Crear, modificar y eliminar productos"
  }
}

# Client App (para que el frontend se conecte)
resource "aws_cognito_user_pool_client" "app" {
  name            = "${var.project_name}-app-client"
  user_pool_id    = aws_cognito_user_pool.main.id
  generate_secret = false

  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  prevent_user_existence_errors = "ENABLED"

  callback_urls = [
    "http://localhost:3000/callback",
    "http://localhost:5173/callback",
    "http://localhost:4200/callback",
    "https://${var.amplify_domain}",
    "https://${var.amplify_domain}/",
  ]
  logout_urls = [
    "http://localhost:5173",
    "https://${var.amplify_domain}",
  ]
}

# Dominio para el Hosted UI
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Grupos: el permiso vive en el grupo, no en el cliente
resource "aws_cognito_user_group" "lectores" {
  name         = "lectores"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Puede consultar productos"
}

resource "aws_cognito_user_group" "editores" {
  name         = "editores"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Puede crear, modificar y eliminar productos"
}

# Usuario de prueba para desarrollo
resource "aws_cognito_user" "test_user" {
  user_pool_id       = aws_cognito_user_pool.main.id
  username           = var.test_user_email
  temporary_password = var.test_user_password
  message_action     = "SUPPRESS"

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  lifecycle {
    ignore_changes = [temporary_password]
  }
}

resource "aws_cognito_user_in_group" "test_editor" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.editores.name
  username     = aws_cognito_user.test_user.username
}

# Usuario con permisos mínimos: solo consulta (productos/read)
resource "aws_cognito_user" "lector" {
  user_pool_id       = aws_cognito_user_pool.main.id
  username           = var.lector_user_email
  temporary_password = var.lector_user_password
  message_action     = "SUPPRESS"

  attributes = {
    email          = var.lector_user_email
    email_verified = "true"
  }

  lifecycle {
    ignore_changes = [temporary_password]
  }
}

resource "aws_cognito_user_in_group" "lector" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.lectores.name
  username     = aws_cognito_user.lector.username
}

# Lambda Pre Token Generation: traduce grupos -> scopes
data "archive_file" "user_token_ms" {
  type        = "zip"
  source_dir  = "${path.module}/user-token-ms"
  output_path = "${path.module}/user-token-ms.zip"
}

resource "aws_lambda_function" "user_token_ms" {
  function_name    = "${var.project_name}-user-token-ms"
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.user_token_ms.output_path
  source_code_hash = data.archive_file.user_token_ms.output_base64sha256
}

# Sin este permiso el trigger existe pero el login falla sin un mensaje claro
resource "aws_lambda_permission" "cognito_invoke" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_token_ms.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
