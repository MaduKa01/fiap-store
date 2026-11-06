#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v trivy >/dev/null || { echo 'Instale Trivy conforme README.'; exit 1; }
export AWS_PROFILE=default AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
mkdir -p avaliacao/trivy .runtime
export TRIVY_CACHE_DIR="$PWD/.runtime/trivy-cache"
scan_dir=$(mktemp -d "$PWD/.runtime/trivy-input.XXXXXX")
trap 'rm -rf "$scan_dir"' EXIT
trivy --version > avaliacao/trivy/versao.txt
# Imagens locais construidas/publicadas por 02-imagens.sh; nenhum login Docker necessario.
# Se as imagens nao estiverem locais, baixe as mesmas tags/digests do ECR antes.
for image in store-api:1.0 store-api:2.0 store-worker:1.0 store-front:1.1; do
 name="${image/:/-}"
 docker image inspect "$REGISTRY/$image" --format '{{json .}}' > "$scan_dir/$name-metadata.json"
 docker save --output "$scan_dir/image.tar" "$REGISTRY/$image"
 trivy image --timeout 15m --no-progress --db-repository public.ecr.aws/aquasecurity/trivy-db:2 --db-repository ghcr.io/aquasecurity/trivy-db:2 --input "$scan_dir/image.tar" --scanners vuln --format json --output "avaliacao/trivy/$name.json"
 rm -f "$scan_dir/image.tar"
done
python3 scripts/resumir-scans.py
