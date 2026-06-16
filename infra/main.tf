locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# AMI mais recente do Amazon Linux 2023 (standard, nao a "minimal").
# A variante minimal nao traz o SSM Agent pre-instalado, o que quebraria o
# deploy via SSM; o padrao "al2023-ami-2023.*" exclui as imagens minimal.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Repositorio ECR onde a imagem da aplicacao sera publicada
resource "aws_ecr_repository" "api" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Security group: libera a porta da aplicacao e o SSH
resource "aws_security_group" "api" {
  name        = "${var.project_name}-sg"
  description = "Permite trafego da aplicacao Flask e SSH"

  ingress {
    description = "Aplicacao Flask"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Trafego de saida liberado"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# IAM role que permite a EC2 puxar imagens do ECR e ser gerenciada via SSM
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

# Leitura do ECR (baixar imagens)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# NOVO NA FASE 2: habilita o SSM Agent a receber comandos do pipeline de CD
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2.name
}

# Instancia EC2 que executa a aplicacao em container Docker
resource "aws_instance" "api" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region     = var.aws_region
    ecr_repository = aws_ecr_repository.api.repository_url
    ecr_registry   = split("/", aws_ecr_repository.api.repository_url)[0]
    app_port       = var.app_port
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-instance"
  })
}
