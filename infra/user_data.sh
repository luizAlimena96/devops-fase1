#!/usr/bin/env bash
set -e

# Instala o Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker

# Garante o SSM Agent (necessario para o deploy via CD). Em AMIs "minimal" do
# AL2023 ele nao vem pre-instalado; nas standard ja vem (instalacao idempotente).
dnf install -y amazon-ssm-agent || true
systemctl enable --now amazon-ssm-agent || true

# Instala o plugin do Docker Compose (orquestracao do container no host)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

mkdir -p /opt/app

# Arquivo de orquestracao, com a imagem do ECR e a porta ja preenchidas pelo Terraform.
cat > /opt/app/docker-compose.yml <<'COMPOSE'
services:
  api:
    image: ${ecr_repository}:latest
    container_name: flask-api
    restart: always
    ports:
      - "${app_port}:5000"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
      interval: 30s
      timeout: 5s
      retries: 3
COMPOSE

# Script de deploy executado a cada nova versao pelo pipeline de CD (via SSM).
cat > /opt/app/deploy.sh <<'DEPLOY'
#!/usr/bin/env bash
set -euo pipefail
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_registry}
cd /opt/app
docker compose pull
docker compose up -d
docker image prune -f
DEPLOY
chmod +x /opt/app/deploy.sh

# Primeiro deploy na inicializacao (tolera a imagem ainda nao publicada no ECR).
/opt/app/deploy.sh || echo "Imagem ainda nao publicada no ECR; o CD fara o primeiro deploy."
