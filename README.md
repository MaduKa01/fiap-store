# FIAP Store — Global Solution

Plataforma Amazon EKS para a aplicação do professor Fabio Bara. Código funcional original preservado; o Dockerfile do front recebeu uma correção de segurança documentada em avaliacao/trivy/JUSTIFICATIVAS.md; documentação original em [docs/README-professor.md](docs/README-professor.md).

## Integrantes

- Ronaldo Madukaife John Attamah — RM 564630.
- Demais integrantes: preencher antes da entrega (o enunciado pede grupo de 2 ou 3).

## Estado da entrega

Cluster fiap-store criado em 05/11/2026 na conta Academy: quatro nós Ready em três zonas, Kubernetes 1.35, EBS CSI ativo, Metrics Server com leituras e VPC CNI com NetworkPolicy habilitada. Imagens ECR publicadas: API 1.0/2.0, worker 1.0 e front 1.1, todas linux/amd64 com usuários não root. Traefik, KEDA e Argo CD instalados; namespaces da aplicação criados. Aplicação implantada por Argo CD com estado Synced/Healthy; página e catálogo responderam HTTP 200 por HTTPS. Rollout real da API 1.0 → 2.0 concluído por commit; avaliação automática em 05/11/2026: 80/80. Scans Trivy produzidos: zero CRITICAL nas quatro imagens atuais; permanecem HIGH na API e no worker. Front 1.1 corrige quatro ocorrências CRITICAL da imagem 1.0. Em 06/11/2026, os dez desafios foram ensaiados com sucesso e a avaliação confirmou novamente 80/80. Relatório com seis prints reais e roteiro de gravação estão em docs/entrega-final/. A gravação do vídeo e a apresentação pelo grupo permanecem a cargo dos integrantes. Os relatórios Trivy serão produzidos com imagens reais. Não são fornecidos resultados fictícios. Atualize este parágrafo após o ensaio e registre as pendências reais.

## Arquitetura e decisões

Traefik recebe HTTPS e encaminha `/api` para FastAPI (8000) e `/` para o front (8080). A API usa HPA de 3 a 6 réplicas, distribuição por zona, PDB mínimo 2 e rolling update sem indisponibilidade planejada. O worker usa KEDA de 0 a 5, observando a lista Redis `pedidos`. O Argo CD sincroniza `k8s/` com prune e selfHeal.

Postgres tem StatefulSet e PVC gp3/EBS CSI com WaitForFirstConsumer e PGDATA em subdiretório. O banco é uma instância única: sua recriação provoca uma interrupção temporária; esta arquitetura exigida no enunciado não oferece alta disponibilidade do banco entre zonas. Redis não persiste a fila: mantenha essa limitação em mente ao demonstrar falhas.

NetworkPolicy em store-data bloqueia ingressos por padrão. Só API, worker e jobs autorizados alcançam Postgres; só API, worker e KEDA alcançam Redis. O CNI precisa efetivamente aplicar a política. store-prod usa PSA restricted. Os três Deployments têm filesystem somente leitura, usuário não root, seccomp e capabilities removidas. Apenas a API monta token e recebe get nodes; desenvolvedores têm leitura de Pods/logs.

O DaemonSet usa node-exporter sem hostPath/hostNetwork e fornece métricas visíveis no contexto do contêiner em cada nó. Não é uma solução completa de monitoramento do host.

## Pré-requisitos

Learner Lab iniciado, créditos disponíveis e região us-east-1. Na máquina: AWS CLI v2, eksctl atual, kubectl, Helm, Docker ativo, Python 3, OpenSSL e Trivy. Não criaremos roles IAM ou OIDC; usamos LabRole. O cluster usa quatro t3.medium em subnets públicas e nenhum NAT Gateway.

No Mac, instale as ferramentas que faltam pelo Homebrew: `brew tap aws/tap` e `brew install aws/tap/eksctl trivy` (verifique antes `command -v eksctl` e `command -v trivy`). No CloudShell, verifique espaço livre com `df -h`: builds e Trivy podem ultrapassar a capacidade disponível; nesse caso use o Mac para as imagens. Fontes oficiais: https://eksctl.io/installation/ e https://trivy.dev/latest/getting-started/installation/.

## Credenciais e isolamento

No Academy, AWS Details → AWS CLI: atualize localmente `~/.aws/credentials` com o bloco de credenciais temporárias. Nunca publique o arquivo nem envie seu conteúdo pelo chat. Renove a cada sessão.

```bash
aws sts get-caller-identity
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
```

Execute todos os comandos na raiz deste projeto. Os scripts usam `.kubeconfig` separado e ignorado pelo Git. Para comandos manuais desta documentação:

```bash
export KUBECONFIG="$PWD/.kubeconfig"
export PATH="$PWD/.runtime/bin:$PATH"
```

O kubectl usado no projeto deve estar a no máximo uma versão menor de distância do servidor. Neste Mac, o binário oficial v1.35.10 foi baixado em `.runtime/bin/kubectl` e verificado por SHA-256, preservando a instalação global v1.37.2. A pasta `.runtime/` não vai para o Git.

## Criar do zero

1. Crie um repositório GitHub público vazio `fiap-store` em sua conta. A pasta desta entrega já contém a aplicação recebida. Não copie configurações ou credenciais de outros projetos.
2. Configure o endereço e a conta (não são segredos):

```bash
export REPO_URL=https://github.com/MaduKa01/fiap-store.git
bash scripts/00-configurar.sh
```

3. Confira cluster.yaml; crie o cluster (normalmente demora dezenas de minutos):

```bash
bash scripts/01-cluster.sh
export KUBECONFIG="$PWD/.kubeconfig"
export PATH="$PWD/.runtime/bin:$PATH"
kubectl get nodes -L topology.kubernetes.io/zone
```

Se EBS CSI falhar por credenciais, examine logs do controller, permissões de LabRole e acesso IMDS dos Pods. Não tente criar IRSA no Academy. Se a criação falhar, inspecione os eventos CloudFormation e remova a criação parcial antes de repetir. Confira suporte da versão 1.35 na conta/região antes da execução.

4. Com Docker ativo, construa e publique API 1.0 e 2.0, worker 1.0 e front 1.1. Todas para linux/amd64. A autenticação Docker/ECR é isolada em diretório temporário ignorado pelo Git e removida ao finalizar o script, sem usar o chaveiro global do Docker:

```bash
bash scripts/02-imagens.sh
bash scripts/03-plataforma.sh
bash scripts/04-segredos-tls.sh
```

A instalação registra versões de Helm em bootstrap/versoes-instaladas.txt e salva o manifesto real do Argo CD. Conserve esses arquivos no commit para documentar o que foi usado. O script de Secrets gera a senha fora do repositório, cria a mesma senha nos dois namespaces e apaga os temporários; ao repetir, reaproveita o Secret do banco. Não altera senha de banco inicializado. O certificado é autoassinado, com SAN do hostname do balanceador; o navegador exige aceite manual. Não é certificado público confiável.

5. Publique os arquivos antes de criar a Application:

```bash
git init -b main
git add .
git diff --cached --stat
# Revise os arquivos; nenhum Secret, chave ou credencial deve estar no commit.
git commit -m "Implementa plataforma EKS da FIAP Store"
git remote add origin "$REPO_URL"
git push -u origin main
bash scripts/05-gitops.sh
kubectl -n argocd get application fiap-store -w
```

Namespaces/configuração/RBAC/rede entram primeiro; banco e Redis depois; Job de migração Sync na wave -5; aplicação na wave 0; HPA/KEDA/Ingress/CronJob na wave 5. O Job retém o sucesso para avaliação e é recriado na próxima sincronização por BeforeHookCreation. Não tem TTL de exclusão. Os Deployments escalados não fixam replicas, e Argo ignora `/spec/replicas` nesses dois recursos.

6. Aguarde o CronJob executar pela agenda de dois minutos. Disparo manual comprova o relatório mas pode não preencher lastSuccessfulTime do CronJob, que o script do professor consulta.

```bash
bash scripts/06-scan.sh
bash scripts/07-validar.sh
```

Examine cada CRITICAL: corrija com justificativa de alteração, ou documente análise específica em avaliacao/trivy/JUSTIFICATIVAS.md. Nunca alegue ausência de vulnerabilidades sem executar o scan.

## Acesso

```bash
kubectl -n traefik get service traefik
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

Loja: `https://HOSTNAME-DO-BALANCEADOR`. Argo CD Application: `https://localhost:8081/applications/fiap-store` durante o port-forward. Usuário Argo CD: admin. Obtenha a senha inicial localmente pelo Secret argocd-initial-admin-secret; não publique o resultado.

## Rollout obrigatório no cluster da demonstração

Edite apenas a imagem do Deployment store-api em k8s/07-app.yaml de `store-api:1.0` para `store-api:2.0`, faça commit e push. Aguarde Argo sincronizar e `kubectl -n store-prod rollout status deploy/store-api`. Verifique o selo da loja e `kubectl -n store-prod get rs -l app=store-api`. Faça rollback por outro commit voltando a imagem para 1.0. Repita em cada cluster novo; histórico do Git não substitui o rollout real.

## Entregar

Complete integrantes, resultados, relatórios e justificativas. Rode a avaliação sem cortes e ensaie [docs/DEMONSTRACAO.md](docs/DEMONSTRACAO.md). Faça commit dos relatórios e evidências sem segredos; então:

```bash
git tag gs-final
git push origin main --tags
```

Verifique também todo o histórico/branches por segredos; `.gitignore` não remove vazamentos anteriores. Não envie credenciais do Academy para GitHub Actions.

## Destruir tudo

A destruição apaga pedidos e relatórios do banco. Quando autorizado e ao encerrar a sessão:

```bash
bash scripts/99-destruir.sh
```

O script remove Application primeiro, namespaces e PVC depois, espera o PV do store-data desaparecer, remove Traefik para excluir o balanceador e remove o cluster com eksctl. Confira no console que nenhum EBS ou LoadBalancer do projeto sobrou; confira também stacks CloudFormation/VPC em caso de falha. ECR é preservado para recriação; para encerrar definitivamente, remova seus três repositórios ECR apenas após conferir que são exclusivos desta atividade. Nunca exclua recursos de outros projetos.

## Uso de IA

OpenAI Codex foi utilizado para leitura do enunciado e contrato dos serviços, elaboração dos manifestos, scripts e documentação. Os integrantes devem revisar e conseguir explicar cada recurso. Validações locais não substituem execução e demonstração no EKS.

## Ensaio e gravação

O roteiro em `docs/entrega-final/Guia-de-gravacao.pdf` organiza a apresentação em 20 minutos. O relatório em `docs/entrega-final/Relatorio-arquitetura-e-evidencias.pdf` contém arquitetura, seis capturas reais e resultados. Evidências do ensaio de 06/11/2026 estão em `evidencias/ensaio-2026-11-06_14-27-06/`. Para repetir os dez testes controlados antes de outra sessão, use `python3 scripts/08-ensaiar.py`: ele cria pedidos de teste, recria Pods, drena um nó sem banco e faz rollback por Git, restaurando API 2.0 e o nó ao final.

Na retomada deste lab, os objetos e o PVC permaneceram, mas `nodeadm-config` havia falhado enquanto a sessão estava encerrada. Os serviços `nodeadm-config` e `nodeadm-run` foram retomados via AWS Systems Manager nas quatro instâncias; não foi necessário excluir o cluster ou o volume. Antes de outra gravação, renove as credenciais e confira que os quatro nós estão Ready e o Argo CD está Synced/Healthy.
