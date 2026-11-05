#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
mkdir -p .runtime
helm repo add traefik https://traefik.github.io/charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
# Registra versoes realmente instaladas; conserve estes arquivos no Git.
helm search repo traefik/traefik --versions -o json > .runtime/traefik-charts.json
helm search repo kedacore/keda --versions -o json > .runtime/keda-charts.json
TRAEFIK_VERSION=$(python3 -c 'import json;print(json.load(open(".runtime/traefik-charts.json"))[0]["version"])')
KEDA_VERSION=$(python3 -c 'import json;print(json.load(open(".runtime/keda-charts.json"))[0]["version"])')
helm upgrade --install traefik traefik/traefik --version "$TRAEFIK_VERSION" -n traefik --create-namespace --set deployment.replicas=2 --wait --timeout 10m
helm upgrade --install keda kedacore/keda --version "$KEDA_VERSION" -n keda --create-namespace --wait --timeout 10m
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
curl -fsSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -o bootstrap/argocd-install.yaml
kubectl apply -n argocd --server-side --force-conflicts -f bootstrap/argocd-install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=600s
printf 'traefik=%s\nkeda=%s\n' "$TRAEFIK_VERSION" "$KEDA_VERSION" > bootstrap/versoes-instaladas.txt
kubectl apply -f k8s/00-namespaces.yaml
