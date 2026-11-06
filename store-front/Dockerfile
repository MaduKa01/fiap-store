# Nginx que roda como usuario nao-root (UID 101) e escuta na porta 8080.
# Com readOnlyRootFilesystem no Kubernetes, monte um emptyDir em /tmp:
# e onde este nginx grava pid e arquivos temporarios.
FROM nginxinc/nginx-unprivileged:1.30-alpine
# Correcao de seguranca: atualiza pacotes vulneraveis da imagem base.
# O usuario root e usado somente durante o build; runtime continua UID 101.
USER root
RUN apk upgrade --no-cache
USER 101
COPY html/ /usr/share/nginx/html/
EXPOSE 8080
