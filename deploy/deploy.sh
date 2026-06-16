#!/usr/bin/env bash
# deploy.sh - publica a versao mais recente da imagem no host.
#
# Passos: autentica no ECR, baixa a imagem mais recente e (re)sobe o
# container com docker compose. E executado automaticamente pelo pipeline
# de CD (job "deploy") atraves do AWS Systems Manager (SSM).
#
# Na EC2, infra/user_data.sh grava uma copia deste script em /opt/app/deploy.sh
# com os valores (regiao, registry, imagem, porta) ja preenchidos.
set -euo pipefail

cd "$(dirname "$0")"

# Carrega variaveis de ambiente se houver um arquivo .env ao lado do script.
set -a
[ -f .env ] && . ./.env
set +a

aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker compose pull        # baixa a imagem :latest publicada pela CI/CD
docker compose up -d       # recria o container com a nova imagem
docker image prune -f      # remove imagens antigas, liberando disco
