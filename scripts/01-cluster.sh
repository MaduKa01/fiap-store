#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
command -v eksctl >/dev/null || { echo 'Instale eksctl conforme README.'; exit 1; }
if rg -q ACCOUNT_ID cluster.yaml 2>/dev/null || grep -q ACCOUNT_ID cluster.yaml; then echo 'Execute 00-configurar.sh primeiro'; exit 1; fi
aws sts get-caller-identity
# Credenciais Kubernetes separadas de outros ambientes locais.
export KUBECONFIG="$PWD/.kubeconfig"
eksctl create cluster -f cluster.yaml --kubeconfig "$KUBECONFIG"
kubectl get nodes -L topology.kubernetes.io/zone
