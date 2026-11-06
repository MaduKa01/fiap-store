#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
umask 077
secret_dir=$(mktemp -d)
trap 'rm -rf "$secret_dir"' EXIT
# Nunca muda a senha de um banco inicializado. Reutiliza o Secret existente.
if kubectl -n store-data get secret store-db-credentials >/dev/null 2>&1; then
 kubectl -n store-data get secret store-db-credentials -o jsonpath='{.data.password}' | openssl base64 -d -A > "$secret_dir/password"
else
 if kubectl -n store-data get pvc -o name | grep -q .; then echo 'PVC existente sem Secret: recupere a senha original antes de continuar.'; exit 1; fi
 openssl rand -hex 24 | tr -d '\n' > "$secret_dir/password"
fi
for ns in store-prod store-data; do
 kubectl -n "$ns" create secret generic store-db-credentials --from-file="password=$secret_dir/password" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
LB_HOST=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -n "$LB_HOST" ]] || { echo 'LoadBalancer ainda sem hostname. Aguarde e repita.'; exit 1; }
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout "$secret_dir/tls.key" -out "$secret_dir/tls.crt" -subj "/CN=fiap-store" -addext "subjectAltName=DNS:$LB_HOST" 2>/dev/null
kubectl -n store-prod create secret tls store-tls --cert="$secret_dir/tls.crt" --key="$secret_dir/tls.key" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
printf 'Loja: https://%s\n' "$LB_HOST"
echo 'Certificado autoassinado para o laboratorio. O navegador exige aceite manual ou confianca local.'
