# Relatorio Final - Projeto DevOps (Fase 1 + Fase 2)

Disciplina de DevOps - PUCRS. Este relatorio consolida o que foi construido na
Fase 1 (Configuracao e Automacao Inicial) e na Fase 2 (Entrega Continua,
Containers e Orquestracao), descrevendo o fluxo completo do commit ate a
aplicacao no ar, a analise dos resultados e as melhorias futuras.

> Observacao: o texto esta em ASCII (sem acentos) para manter o padrao do
> restante do projeto.

---

## 1. Visao geral

O projeto usa uma API REST simples em Flask (CRUD de "itens" em memoria + um
endpoint de health check) como alvo de uma esteira completa de DevOps:

- Integracao Continua (CI) com GitHub Actions.
- Testes automatizados com pytest e analise estatica com flake8.
- Infraestrutura como Codigo (IaC) com Terraform na AWS.
- Containerizacao com Docker e orquestracao com Docker Compose.
- Entrega Continua (CD) com publicacao da imagem no Amazon ECR e deploy na
  EC2 atraves do AWS Systems Manager (SSM).

Variaveis padrao da infraestrutura: `project_name = devops-fase1-api`,
`aws_region = us-east-1`, `app_port = 5000`, `instance_type = t3.micro`.

---

## 2. Fase 1 - Configuracao e Automacao Inicial

### 2.1 Aplicacao e testes

- `app/app.py`: API Flask com `/health` e CRUD de `/items`.
- `tests/test_app.py`: testes de unidade/integracao executados via pytest, com
  relatorio de cobertura (`--cov=app`).
- `.flake8` e `pytest.ini`: padronizam lint e execucao dos testes.

### 2.2 Integracao Continua (CI)

O workflow `.github/workflows/ci.yml` roda em cada `push` e `pull_request` para
a `main`, com tres jobs:

1. **Lint e Testes** (`lint-and-test`): instala dependencias, roda `flake8` e
   `pytest` com cobertura.
2. **Build da imagem Docker** (`docker-build`): valida o `Dockerfile`
   construindo a imagem (`flask-api:ci`).
3. **Validacao Terraform** (`terraform-validate`): `fmt -check`, `init
   -backend=false` e `validate` da infra.

### 2.3 Infraestrutura como Codigo (Terraform)

O diretorio `infra/` provisiona na AWS:

- **ECR** (`aws_ecr_repository`): registro privado de imagens, com scan on push.
- **EC2** (Amazon Linux 2023): host que roda o container da aplicacao.
- **Security Group**: libera a porta da aplicacao e SSH.
- **IAM Role / Instance Profile**: permite a EC2 puxar imagens do ECR.
- **user_data.sh**: bootstrap da instancia (instala Docker e sobe o container).

---

## 3. Fase 2 - Entrega Continua, Containers e Orquestracao

A Fase 2 foi construida sobre a Fase 1 sem quebrar nada do que ja existia.

### 3.1 Containerizacao (Docker)

- O `Dockerfile` (Fase 1) ja empacota a aplicacao e a executa com `gunicorn`.
- A imagem passa a ser publicada no ECR com duas tags a cada deploy:
  - `<github.sha>`: rastreabilidade (qual commit gerou a imagem).
  - `latest`: tag movel consumida pelo host no deploy.

### 3.2 Orquestracao (Docker Compose)

Foi adicionado um `docker-compose.yml` na raiz para orquestrar o container:

- Servico `api`, `container_name: flask-api`, `restart: always`.
- `image: ${ECR_IMAGE:-flask-api:local}` com `build: .` para uso local.
- Porta `${APP_PORT:-5000}:5000`.
- `healthcheck` chamando `http://localhost:5000/health`.

No host (EC2), um arquivo equivalente e gerado pelo `infra/user_data.sh`, ja com
a URL do ECR e a porta preenchidas pelo Terraform.

### 3.3 Entrega Continua (CD via SSM)

O `ci.yml` foi renomeado para **CI/CD** e ganhou um quarto job, `deploy`, que:

- Depende dos tres jobs anteriores (`needs: [lint-and-test, docker-build,
  terraform-validate]`).
- So executa em `push` na `main`
  (`if: github.ref == 'refs/heads/main' && github.event_name == 'push'`).
  Pull requests apenas validam, nao implantam.
- Configura credenciais AWS (`aws-actions/configure-aws-credentials@v4`) a partir
  dos secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`.
- Faz login no ECR (`aws-actions/amazon-ecr-login@v2`).
- Constroi e publica a imagem com as tags `<github.sha>` e `latest`.
- Implanta na EC2 via SSM:
  1. Descobre o `INSTANCE_ID` por `aws ec2 describe-instances` filtrando por
     `tag:Project=devops-fase1-api` e estado `running`.
  2. Dispara `aws ssm send-command` (documento `AWS-RunShellScript`) executando
     `/opt/app/deploy.sh`.
  3. Aguarda com `aws ssm wait command-executed` e imprime o
     `StandardOutputContent` via `aws ssm get-command-invocation`.

Para o SSM funcionar, a IAM Role da EC2 recebeu a policy gerenciada
`AmazonSSMManagedInstanceCore` (alem da de leitura do ECR ja existente).

### 3.4 Script de deploy no host

- `deploy/deploy.sh` (versionado no repo) e `infra/user_data.sh` (que grava
  `/opt/app/deploy.sh` na EC2) executam o mesmo fluxo:
  `aws ecr get-login-password | docker login` -> `docker compose pull` ->
  `docker compose up -d` -> `docker image prune -f`.
- O `user_data.sh` ainda instala o plugin do Docker Compose, cria `/opt/app`,
  escreve o `docker-compose.yml` e roda o primeiro deploy na inicializacao
  (tolerando a imagem ainda nao existir no ECR).

---

## 4. Fluxo completo: do commit ate a app no ar

1. **Desenvolvedor** faz `commit` e `push` na branch `main`.
2. **CI** dispara automaticamente:
   - Lint e Testes (flake8 + pytest).
   - Build da imagem Docker (valida o Dockerfile).
   - Validacao Terraform (fmt, init, validate).
3. **CD** (job `deploy`, somente em push na main):
   - Autentica na AWS e faz login no ECR.
   - Build + push da imagem com tags `<sha>` e `latest`.
   - Localiza a EC2 por tag e dispara o `deploy.sh` via SSM.
4. **Host (EC2)** executa `/opt/app/deploy.sh`:
   - Login no ECR, `docker compose pull`, `up -d` e limpeza de imagens.
5. **Usuarios** acessam a aplicacao em `http://<ip-publico>:5000`.

O diagrama completo esta em [`fluxograma-devops.svg`](fluxograma-devops.svg)
(versao em imagem: [`fluxograma-devops.png`](fluxograma-devops.png)).

---

## 5. Analise de resultados

- **Automacao ponta a ponta**: um `push` na `main` valida, testa, empacota,
  publica e implanta sem intervencao manual, reduzindo erro humano.
- **Rastreabilidade**: a tag `<github.sha>` permite identificar exatamente qual
  commit esta rodando e facilita um rollback manual para uma imagem anterior.
- **Deploy sem SSH**: o uso do SSM elimina a necessidade de abrir e expor a
  porta 22 para o pipeline e de gerenciar chaves SSH no CI, melhorando a
  seguranca.
- **Reprodutibilidade**: toda a infraestrutura e descrita em Terraform e o
  ambiente de execucao e um container, garantindo paridade entre maquinas.
- **Qualidade**: lint e testes sao porta de entrada obrigatoria; o deploy so
  ocorre se os jobs anteriores passarem.

---

## 6. Melhorias futuras

- **OIDC** no GitHub Actions em vez de chaves de acesso estaticas
  (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`), usando credenciais temporarias.
- **Backend remoto do Terraform** em S3 + DynamoDB (state compartilhado e lock),
  no lugar do state local.
- **Restringir os CIDRs do Security Group** (hoje `0.0.0.0/0`), liberando apenas
  os IPs necessarios para a aplicacao e para o SSH.
- **Rollback automatico por healthcheck**: se o container novo nao ficar
  saudavel, voltar para a imagem anterior automaticamente.
- **Alta disponibilidade** com ECS ou EKS (multiplas instancias/tasks atras de
  um load balancer) em vez de uma unica EC2.
- **Monitoramento e logs no CloudWatch** (metricas, alarmes e logs centralizados)
  para observabilidade do servico.

---

## 7. Conclusao

O projeto evoluiu de uma base de CI + IaC (Fase 1) para uma esteira de Entrega
Continua completa (Fase 2), com containerizacao, orquestracao e deploy
automatizado e seguro via SSM. O resultado e um fluxo reproduzivel do commit ate
a aplicacao no ar, com pontos claros de evolucao rumo a um ambiente de producao
mais robusto (HA, observabilidade e seguranca reforcada).
