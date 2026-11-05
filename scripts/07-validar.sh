#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
kubectl -n store-prod rollout status deployment/store-api --timeout=600s
kubectl -n store-prod wait --for=condition=complete job/db-migrate --timeout=300s
kubectl top pods -n store-prod
kubectl -n store-prod get cronjob store-report
kubectl -n argocd get application fiap-store
LB_HOST=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
mkdir -p evidencias
bash avaliacao/verifica-gs.sh "https://$LB_HOST" | tee evidencias/verificacao.txt
