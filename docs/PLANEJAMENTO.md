# Documentação de Planejamento — Fase 1: Configuração e Automação Inicial

> **Repositório do projeto:** `https://github.com/SEU-USUARIO/devops-fase1`
> _(substitua pelo link real após criar o repositório no GitHub — ele contém o pipeline de CI e os scripts de IaC descritos abaixo)._

---

## 1. Descrição do Projeto, Objetivos e Requisitos

### Descrição
O projeto consiste em uma **API REST** desenvolvida em Python com o framework Flask, que serve como aplicação-alvo para a construção de uma esteira completa de DevOps. A API expõe um CRUD de "itens" em memória e um endpoint de verificação de saúde (`/health`), sendo simples o bastante para manter o foco nas práticas de automação, mas completa o suficiente para exercitar testes, integração contínua e provisionamento de infraestrutura.

Nesta primeira fase, o objetivo não é a aplicação em si, e sim a **automação em torno dela**: garantir que cada alteração de código seja verificada automaticamente e que a infraestrutura de execução possa ser criada de forma reproduzível, versionada e sem passos manuais.

### Objetivos
O objetivo geral é estabelecer a base de automação do ciclo de vida do software, cobrindo desde a verificação do código até a definição da infraestrutura. De forma específica, busca-se implantar um pipeline de integração contínua que rode a cada alteração, criar uma suíte de testes automatizados executada por esse pipeline, e descrever toda a infraestrutura como código para que ela seja versionável e recriável. Por fim, pretende-se documentar o planejamento de modo que qualquer pessoa da equipe consiga entender e reproduzir o ambiente.

### Requisitos

**Requisitos funcionais da aplicação:** a API deve permitir criar, listar, consultar e remover itens, além de oferecer um endpoint de health check que retorne o estado do serviço.

**Requisitos não funcionais e de processo:** todo o código deve ficar versionado no GitHub; cada push ou pull request para a branch principal deve disparar a verificação automática; os testes precisam passar e o código precisa estar dentro do padrão de estilo (lint) para que a mudança seja considerada válida; e a infraestrutura deve ser inteiramente descrita em arquivos de código (Terraform), sem configuração manual no console da AWS.

---

## 2. Plano de Integração Contínua (CI)

A integração contínua é implementada com **GitHub Actions**. O arquivo de workflow fica em `.github/workflows/ci.yml` e é acionado automaticamente em dois eventos: `push` na branch `main` e abertura/atualização de `pull request` para a `main`. Essa estratégia garante que nenhum código entre na branch principal sem antes passar pelas verificações.

O pipeline é dividido em três jobs com responsabilidades claras:

O primeiro job, **Lint e Testes**, prepara um ambiente Python 3.12, instala as dependências da aplicação e de desenvolvimento, roda o `flake8` para verificar o padrão de estilo e, em seguida, executa a suíte de testes com `pytest`, gerando também o relatório de cobertura. É o coração da verificação de qualidade.

O segundo job, **Build da imagem Docker**, só roda após o primeiro passar (dependência declarada com `needs`). Ele constrói a imagem definida no `Dockerfile`, garantindo que a aplicação continua "empacotável" e pronta para ser implantada — uma checagem que antecipa problemas que só apareceriam no momento do deploy.

O terceiro job, **Validação Terraform**, verifica a infraestrutura como código: confere a formatação (`terraform fmt -check`), inicializa o diretório sem backend remoto e valida a sintaxe e a consistência da configuração (`terraform validate`). Assim, erros nos scripts de infraestrutura são detectados na CI, e não na hora de aplicá-los.

O critério de sucesso do pipeline é simples: **todos os jobs precisam terminar em verde**. Qualquer falha de lint, teste ou validação bloqueia a integração e sinaliza claramente onde está o problema.

---

## 3. Especificação da Infraestrutura

A infraestrutura é descrita como código com **Terraform**, tendo a **AWS** como provedor de nuvem. Todos os arquivos ficam no diretório `infra/`, organizados por responsabilidade: `provider.tf` (provider e versões), `variables.tf` (parâmetros de entrada), `main.tf` (recursos), `outputs.tf` (saídas) e `user_data.sh` (script de inicialização da instância).

A topologia provisionada é composta pelos seguintes recursos. Um **repositório ECR** (Elastic Container Registry) armazena a imagem Docker da aplicação. Uma **instância EC2** do tipo `t3.micro`, baseada na AMI mais recente do Amazon Linux 2023, executa a aplicação dentro de um container Docker. Um **Security Group** controla o tráfego de rede, liberando a porta da aplicação (5000) para acesso externo e a porta 22 (SSH) para administração. Por fim, uma **IAM Role** com um *instance profile* concede à EC2 permissão somente leitura sobre o ECR, permitindo que ela baixe a imagem da aplicação sem credenciais embutidas no servidor.

O script `user_data.sh` é executado na primeira inicialização da instância: ele instala e habilita o Docker, autentica no ECR e executa o container da aplicação de forma persistente (`--restart always`). A publicação da imagem no ECR e a entrega automatizada (CD) ficam para as fases seguintes do projeto; nesta fase, a entrega é a **definição completa e validável** dessa infraestrutura.

Os parâmetros principais (região, tipo de instância, porta da aplicação, CIDR de SSH e nome do projeto) são expostos como variáveis com valores padrão, o que torna o ambiente facilmente ajustável sem alterar o código dos recursos. As saídas (`outputs`) entregam, ao final do `apply`, a URL do ECR, o IP público da instância e a URL de acesso à aplicação.

---

## 4. Entregáveis desta Fase

Esta fase entrega, dentro do repositório indicado no topo deste documento, esta documentação de planejamento; o pipeline de integração contínua configurado em `.github/workflows/ci.yml`; os scripts de infraestrutura como código no diretório `infra/`; e a suíte de testes automatizados em `tests/`, já integrada ao pipeline e executada a cada alteração.
