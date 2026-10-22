output "app_id" {
  value = aws_amplify_app.front.id
}

output "default_domain" {
  description = "Dominio que asigna AWS (no existe hasta crear la app)"
  value       = aws_amplify_app.front.default_domain
}

output "url" {
  value = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.front.default_domain}"
}
