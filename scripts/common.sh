#!/usr/bin/env bash
# Carregado pelos scripts de operacao: somente o cluster desta atividade.
export PATH="$PWD/.runtime/bin:$PATH"
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
export KUBECONFIG="$PWD/.kubeconfig"
if [[ ! -f "$KUBECONFIG" ]]; then aws eks update-kubeconfig --name fiap-store --region us-east-1 --kubeconfig "$KUBECONFIG" >/dev/null; fi
server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
[[ "$server" == *eks.amazonaws.com* ]] || { echo 'Contexto inesperado; abortando.'; exit 1; }
