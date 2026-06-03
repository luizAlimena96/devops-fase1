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
