#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
if grep -q REPO_URL bootstrap/application.yaml; then echo 'Configure o repositorio antes.'; exit 1; fi
# Publique o commit inicial antes desta etapa; Argo baixa o conteudo do GitHub.
kubectl apply -f bootstrap/application.yaml
kubectl -n argocd get application fiap-store
printf '\nAcompanhe: kubectl -n argocd get application fiap-store -w\n'
