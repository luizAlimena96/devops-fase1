# DevOps — Fase 1: Configuração e Automação Inicial

API REST em Flask usada como alvo para uma esteira de DevOps: integração contínua (GitHub Actions), testes automatizados (pytest) e infraestrutura como código (Terraform/AWS).

A documentação de planejamento completa está em [`docs/PLANEJAMENTO.md`](docs/PLANEJAMENTO.md).

## Estrutura

```
devops-fase1/
├── app/                      # Aplicação Flask
│   ├── app.py                # API REST (itens + health check)
│   └── requirements.txt      # Dependências de runtime
├── tests/
│   └── test_app.py           # Testes automatizados (pytest)
├── infra/                    # Infraestrutura como código (Terraform)
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf               # ECR, EC2, Security Group, IAM
│   ├── outputs.tf
│   └── user_data.sh
├── .github/workflows/ci.yml  # Pipeline de CI
├── docs/PLANEJAMENTO.md      # Documentação de planejamento
├── Dockerfile
├── requirements-dev.txt
├── pytest.ini
└── .flake8
```

## Rodando localmente

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt -r requirements-dev.txt

# Subir a API
python -m app.app          # http://localhost:5000

# Rodar lint e testes (o que a CI também faz)
flake8 app tests
pytest --cov=app --cov-report=term-missing
```

## Endpoints

| Método | Rota              | Descrição                  |
|--------|-------------------|----------------------------|
| GET    | `/health`         | Verificação de saúde       |
| GET    | `/items`          | Lista os itens             |
| POST   | `/items`          | Cria um item (`{"name"}`)  |
| GET    | `/items/<id>`     | Consulta um item           |
| DELETE | `/items/<id>`     | Remove um item             |

## Pipeline de CI

A cada `push` ou `pull request` para `main`, o GitHub Actions executa:
1. **Lint e Testes** — flake8 + pytest com cobertura
2. **Build da imagem Docker** — valida o `Dockerfile`
3. **Validação Terraform** — `fmt`, `init` e `validate` da infra

## Pipeline de CD (Fase 2)

A partir da Fase 2 o workflow passou a se chamar **CI/CD** e ganhou um quarto job,
`deploy` (Entrega Contínua), que **só roda em `push` na `main`** (em pull requests
os três jobs anteriores apenas validam, sem implantar). Ele depende dos jobs
`lint-and-test`, `docker-build` e `terraform-validate` e executa:

1. **Credenciais AWS** — `aws-actions/configure-aws-credentials@v4`, usando os
   secrets e a região `us-east-1`.
2. **Login no ECR** — `aws-actions/amazon-ecr-login@v2`.
3. **Build + push da imagem** — publica no ECR com duas tags: `github.sha`
   (rastreabilidade) e `latest` (consumida pelo host).
4. **Deploy via AWS SSM** — descobre a instância EC2 pela tag
   `Project=devops-fase1-api` (estado `running`), dispara
   `aws ssm send-command` (documento `AWS-RunShellScript`) executando
   `/opt/app/deploy.sh`, aguarda a conclusão e imprime a saída do comando.

No host, `/opt/app/deploy.sh` autentica no ECR e roda
`docker compose pull && docker compose up -d && docker image prune -f`,
recriando o container `flask-api` com a nova imagem. A orquestração local usa o
[`docker-compose.yml`](docker-compose.yml) da raiz.

> O deploy via SSM dispensa SSH/chaves no pipeline. Para isso, a IAM Role da EC2
> recebe a policy `AmazonSSMManagedInstanceCore` (além da leitura do ECR).

### Secrets necessários

Configure em **Settings → Secrets and variables → Actions** do repositório:

| Secret                  | Descrição                                  |
|-------------------------|--------------------------------------------|
| `AWS_ACCESS_KEY_ID`     | Access key da AWS usada pelo job de deploy |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondente                  |

O diagrama do fluxo completo está em
[`docs/fluxograma-devops.png`](docs/fluxograma-devops.png) e o relatório
consolidado em [`docs/RELATORIO.md`](docs/RELATORIO.md).

## Infraestrutura (Terraform)

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Provisiona um repositório ECR, uma instância EC2 (Amazon Linux 2023) rodando a
aplicação em Docker, um Security Group e uma IAM Role com acesso de leitura ao ECR.
Requer credenciais AWS configuradas no ambiente.
