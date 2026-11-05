#!/usr/bin/env bash
# DESTRUTIVO: apaga os dados do banco e a infraestrutura desta atividade.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
printf 'Conta atual: '; aws sts get-caller-identity --query Account --output text
read -r -p 'Digite DESTRUIR fiap-store para apagar o banco e o cluster: ' resposta
[[ "$resposta" == 'DESTRUIR fiap-store' ]] || exit 1
kubectl -n argocd delete application fiap-store --ignore-not-found --wait=true
# Garante que o app nao vai recriar namespaces.
kubectl delete namespace store-prod store-data store-observability --ignore-not-found --wait=true --timeout=10m
for i in $(seq 1 60); do
 remaining=$(kubectl get pv -o json | python3 -c 'import json,sys; print(sum(p.get("spec",{}).get("claimRef",{}).get("namespace")=="store-data" for p in json.load(sys.stdin)["items"]))')
 [[ "$remaining" == 0 ]] && break
 sleep 5
done
[[ "$remaining" == 0 ]] || { echo 'PV ainda existe; resolva a exclusao EBS antes de remover o cluster.'; exit 1; }
helm uninstall traefik -n traefik
# Aguarda a remocao do LB antes de apagar sua VPC.
sleep 20
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction --wait
echo 'Confira EC2 > Volumes e Load Balancers para garantir que nao sobraram recursos. ECR e relatorios foram preservados.'
