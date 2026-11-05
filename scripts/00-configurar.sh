#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${REPO_URL:?Defina REPO_URL=https://github.com/SEU-USUARIO/fiap-store.git}"
[[ "$REPO_URL" =~ ^https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?$ ]] || { echo 'URL GitHub invalida'; exit 1; }
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ACCOUNT_ID REPO_URL
python3 - <<'PY'
from pathlib import Path
import os
for p in [Path('cluster.yaml'),Path('bootstrap/application.yaml'),*Path('k8s').glob('*.yaml')]:
 t=p.read_text().replace('ACCOUNT_ID',os.environ['ACCOUNT_ID']).replace('REPO_URL',os.environ['REPO_URL']);p.write_text(t)
PY
printf 'Configurado para conta %s. Confira cluster.yaml antes de criar.\n' "$ACCOUNT_ID"
