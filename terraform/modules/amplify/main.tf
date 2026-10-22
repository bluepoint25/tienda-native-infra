# App de Amplify conectada al repositorio: compila en cada push a main (amplify.yml del repo)
resource "aws_amplify_app" "front" {
  name       = var.app_name
  repository = var.repository
  platform   = "WEB"

  # SPA: cualquier ruta sin extensión de archivo estático sirve index.html (si no, /callback daría 404)
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }

  # El token de GitHub se configuró al conectar el repo en la consola; Terraform no lo conoce ni debe pisarlo
  lifecycle {
    ignore_changes = [access_token, oauth_token, build_spec]
  }
}

resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.front.id
  branch_name       = "main"
  framework         = "React"
  stage             = "PRODUCTION"
  enable_auto_build = true

  # Las tres configuraciones que deben coincidir salen de Terraform, no de valores copiados a mano
  environment_variables = {
    VITE_COGNITO_USER_POOL_ID = var.cognito_user_pool_id
    VITE_COGNITO_CLIENT_ID    = var.cognito_client_id
    VITE_COGNITO_DOMAIN       = var.cognito_domain
    VITE_COGNITO_REGION       = var.aws_region
    VITE_API_BASE_URL         = var.api_base_url
    # ms-mensajeria se publica en el mismo API Gateway (rutas /api/v1/eventos y /api/v1/admin)
    VITE_MENSAJERIA_URL = var.api_base_url
  }
}
