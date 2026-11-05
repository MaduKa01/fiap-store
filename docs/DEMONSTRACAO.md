# Ensaio dos dez desafios

Execute na raiz com `export KUBECONFIG="$PWD/.kubeconfig"`. Deixe a loja aberta e observe pedidos, versão e painel. A disponibilidade do banco é limitada pela instância única exigida no trabalho.

1. **Self-healing:** `kubectl -n store-prod delete pod NOME-DE-UM-POD-API`. Observe `kubectl -n store-prod get pods -l app=store-api -w`. Deployment/ReplicaSet recompõe a réplica; Services encaminham a Pods prontos. A exclusão direta não é protegida pelo PDB.
2. **Manutenção:** descubra o nó do banco com `kubectl -n store-data get pod store-db-0 -o wide`. Escolha OUTRO nó. Execute `kubectl drain NO-ESCOLHIDO --ignore-daemonsets --delete-emptydir-data --timeout=10m`. PDB limita interrupção voluntária; se faltar capacidade, a drenagem pode bloquear. Nunca force. Finalize com `kubectl uncordon NO-ESCOLHIDO`.
3. **Rollback GitOps:** edite a tag do Deployment API, commit/push 2.0 e aguarde. Depois commit/push 1.0. Não use rollout undo: Argo restauraria a versão do Git.
4. **KEDA:** aguarde fila vazia e worker em zero. Gere 50 pedidos pelo painel. Observe `kubectl -n store-prod get deploy store-worker -w` e `kubectl -n store-prod get scaledobject,hpa`. KEDA ativa pelo Redis, HPA calcula mais réplicas e o cooldown permite retornar a zero. Se a fila esvaziar rapidamente, talvez o pico não alcance cinco Pods.
5. **Persistência:** anote pedidos, apague `kubectl -n store-data delete pod store-db-0` e aguarde prontidão. O StatefulSet reutiliza o PVC e o EBS da mesma zona. Haverá interrupção temporária do banco; os dados devem permanecer.
6. **Pod Security:** `kubectl -n store-prod run psa-negado --image=busybox:1.36 --privileged --restart=Never -- sleep 60`. A criação deve ser recusada por restricted. Nenhum Pod privilegiado deve entrar.
7. **RBAC:** use `kubectl auth can-i VERBO RECURSO -n store-prod --as=dev.aluno --as-group=fiap:devs`. Teste list pods (yes), get pods --subresource=log (yes), delete pods (no), get secrets (no), create pods --subresource=exec (no). A identidade que testa precisa ter permissão de impersonation; o grupo não cria automaticamente usuários IAM.
8. **Drift:** `kubectl -n store-prod delete service store-front`. Argo recria via selfHeal. Pode existir breve interrupção do frontend enquanto o Service está ausente.
9. **Rede:** `kubectl -n store-prod exec deploy/store-front -- nc -z -w 3 store-db.store-data.svc.cluster.local 5432` deve falhar. `kubectl -n store-prod exec deploy/store-api -- python -c "import socket; socket.create_connection(('store-db.store-data.svc.cluster.local',5432),3); print('conectou')"` deve funcionar. NetworkPolicy exige CNI com suporte ativo; a existência do YAML não comprova o bloqueio.
10. **Relatório:** `kubectl -n store-prod create job --from=cronjob/store-report report-manual-$(date +%s)`. Aguarde sucesso e abra relatórios no painel. Para E2, aguarde também uma execução realmente agendada, pois o avaliador lê lastSuccessfulTime do CronJob.

## Vinte minutos

- 2 min: loja HTTPS e painel.
- 5 min: `bash scripts/07-validar.sh` e script do professor sem cortes.
- 9 min: três desafios; cada integrante conduz pelo menos um.
- 4 min: explicar decisões, limites e recuperação.

Antes da apresentação: lab ativo, credenciais renovadas, cluster criado com antecedência, rollout real 1.0 → 2.0 realizado nesse cluster, CronJob com sucesso e relatórios Trivy revisados. Não destrua o cluster antes do horário da demonstração.
