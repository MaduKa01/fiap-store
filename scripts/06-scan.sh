#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v trivy >/dev/null || { echo 'Instale Trivy conforme README.'; exit 1; }
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"
mkdir -p avaliacao/trivy
critical=0
for image in store-api:1.0 store-api:2.0 store-worker:1.0 store-front:1.0; do
 report="avaliacao/trivy/${image/:/-}.json"
 trivy image --scanners vuln --format json --output "$report" "$REGISTRY/$image"
 if ! trivy image --scanners vuln --severity CRITICAL --exit-code 1 "$REGISTRY/$image" > "${report%.json}-critical.txt"; then critical=1; fi
done
if [[ "$critical" == 1 ]]; then echo 'Ha CRITICAL ou falha de scan: examine os relatorios e documente correcoes/justificativas.'; exit 1; fi
