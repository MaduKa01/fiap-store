#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 AWS_PROFILE=default
# Autenticacao ECR temporaria, sem usar ou alterar o chaveiro global do Docker.
umask 077
export DOCKER_HOST="$(docker context inspect --format '{{.Endpoints.docker.Host}}')"
mkdir -p .runtime
export DOCKER_CONFIG="$(mktemp -d "$PWD/.runtime/docker-auth.XXXXXX")"
trap 'rm -rf "$DOCKER_CONFIG"' EXIT
# Mantem os plugins de build disponiveis com a configuracao isolada.
if [[ -d "$HOME/.docker/cli-plugins" ]]; then ln -s "$HOME/.docker/cli-plugins" "$DOCKER_CONFIG/cli-plugins"; fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
for repo in store-api store-worker store-front; do
 if ! aws ecr describe-repositories --repository-names "$repo" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "$repo" --image-scanning-configuration scanOnPush=true >/dev/null
 fi
done
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
for v in 1.0 2.0; do docker build --platform linux/amd64 --build-arg "APP_VERSION=$v" -t "$REGISTRY/store-api:$v" store-api; docker push "$REGISTRY/store-api:$v"; done
for component in store-worker store-front; do
 version=1.0
 [[ "$component" == store-front ]] && version=1.1
 docker build --platform linux/amd64 -t "$REGISTRY/$component:$version" "$component"
 docker push "$REGISTRY/$component:$version"
done
