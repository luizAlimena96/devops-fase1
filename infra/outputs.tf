output "ecr_repository_url" {
  description = "URL do repositorio ECR para publicar a imagem da aplicacao"
  value       = aws_ecr_repository.api.repository_url
}

output "instance_public_ip" {
  description = "IP publico da instancia EC2"
  value       = aws_instance.api.public_ip
}

output "application_url" {
  description = "URL de acesso a aplicacao"
  value       = "http://${aws_instance.api.public_ip}:${var.app_port}"
}
