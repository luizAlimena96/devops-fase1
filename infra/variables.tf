variable "aws_region" {
  description = "Regiao AWS onde os recursos serao criados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos"
  type        = string
  default     = "devops-fase1-api"
}

variable "instance_type" {
  description = "Tipo da instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Porta em que a aplicacao Flask responde"
  type        = number
  default     = 5000
}

variable "allowed_ssh_cidr" {
  description = "Bloco CIDR autorizado a acessar a porta SSH (22)"
  type        = string
  default     = "0.0.0.0/0"
}
