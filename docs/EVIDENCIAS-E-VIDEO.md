# Planejamento das evidências e do vídeo

Solicitado por Ronaldo: preparar, ao concluir o ambiente, documento com prints de partes da arquitetura e roteiro para gravar vídeo. Nenhuma captura ou teste pendente deve ser apresentado como realizado.

## Capturas a produzir no ambiente real

| Parte | Evidência visual | O que explicar |
|---|---|---|
| Arquitetura | Diagrama com AWS/EKS, namespaces, rotas e dependências | Caminho HTTPS → Traefik → API/front → dados e fila |
| EKS | Cluster ACTIVE e quatro nós Ready com zonas | Distribuição entre zonas e papel dos nós |
| ECR | API 1.0/2.0, worker 1.0 e front 1.0 | Imagens linux/amd64 e versões sem latest |
| Entrada HTTPS | LoadBalancer Traefik, Ingress e loja no navegador | /api para API, / para front, TLS do laboratório |
| Aplicação | Pods e painel da plataforma | Réplicas, probes, recursos e Downward API |
| Dados | StatefulSet, PVC Bound, StorageClass EBS CSI | Persistência em uma zona e limitação do banco único |
| Segurança | NetworkPolicy, RBAC e PSA restricted | Front bloqueado no banco; API permitida; devs somente leitura |
| Escalonamento | HPA com métricas e KEDA/worker antes, durante e após pedidos | Mínimo de três APIs e worker de zero até cinco |
| Jobs | db-migrate Complete e CronJob com execução agendada bem-sucedida | Migração idempotente e geração de relatórios |
| GitOps | Argo CD Application Synced/Healthy e árvore de recursos | prune, selfHeal e alteração por commit |
| Qualidade | Resultado real do verifica-gs.sh e relatórios Trivy | Pontuação obtida, vulnerabilidades e pendências reais |

## Cuidados com capturas

Não mostrar arquivo de credenciais AWS, senha do banco, valores de Secrets, token ECR, senha/token do Argo CD ou chave TLS. Nomes dos recursos e status podem aparecer. Identificar data, recurso e conclusão de cada print. Informar se o certificado é autoassinado. Não prometer alta disponibilidade do banco único.

## Estrutura do documento final

1. Identificação: Ronaldo Madukaife John Attamah, RM 564630, demais integrantes a confirmar.
2. Objetivo e diagrama da arquitetura implantada.
3. Componentes AWS e Kubernetes, com prints reais e legendas curtas.
4. Evidências de segurança, escalonamento, GitOps e persistência.
5. Resultados efetivos de avaliação e scan; limitações encontradas.
6. Procedimento de criação e destruição; links para repositório e aplicação quando definidos.

## Roteiro inicial do vídeo

Tempo e formato a confirmar antes da produção. Sequência sugerida: apresentar arquitetura; mostrar EKS/ECR; abrir loja HTTPS e painel; demonstrar pedidos/KEDA; mostrar HPA, dados e segurança; mostrar Argo CD e mudança por Git; executar avaliação e concluir com resultados reais. Gravar somente depois do ensaio e das correções.

O enunciado recebido determina demonstração ao vivo de 20 minutos e afirma que vídeo não a substitui. Confirmar com o professor se houve nova orientação; preparar vídeo como material adicional enquanto não houver alteração informada.
