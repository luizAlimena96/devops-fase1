set -e

dnf update -y
dnf install -y docker
systemctl enable --now docker

# Autentica no ECR
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_repository}

# Puxa e executa a imagem da aplicacao.
# A publicacao da imagem no ECR e feita pela pipeline de CD (fase posterior).
docker pull ${ecr_repository}:latest || echo "Imagem ainda nao publicada no ECR"

docker run -d --restart always \
  -p ${app_port}:${app_port} \
  --name flask-api \
  ${ecr_repository}:latest || true
