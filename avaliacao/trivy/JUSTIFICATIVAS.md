# Vulnerabilidades: resultados e correção aplicada

Scan real em 05/11/2026, Trivy 0.76.1. Veja os relatórios JSON completos, `versao.txt` e `resumo.json`. Foram analisados arquivos Docker exportados das mesmas imagens linux/amd64 construídas e publicadas no ECR. Arquivos de imagem e cache ficam fora do Git; relatórios e digests ficam no repositório.

## Imagens atuais

| Imagem | CRITICAL | HIGH | Situação |
|---|---:|---:|---|
| store-api:1.0 | 0 | 55 | preservada para rollback |
| store-api:2.0 | 0 | 55 | versão da API implantada |
| store-worker:1.0 | 0 | 52 | imagem do worker e relatório |
| store-front:1.1 | 0 | 0 | imagem corrigida do front |

Zero CRITICAL não significa ausência de risco. Há também MEDIUM, LOW e UNKNOWN na API/worker; os números e pacotes constam nos relatórios completos. Essas imagens mantêm o código e dependências recebidos do professor; atualizações e testes de compatibilidade continuam necessários para uso de produção. Os controles Kubernetes reduzem o impacto potencial, mas não corrigem vulnerabilidades de bibliotecas.

## Correção do front 1.0 → 1.1

O scan inicial encontrou quatro ocorrências CRITICAL em três CVEs. Os relatórios originais foram preservados em `historico/`; a imagem 1.0 não é a versão selecionada nos manifestos. As ocorrências não foram ocultadas nem descartadas como falso positivo.

| CVE | Pacote na imagem 1.0 | Versão original | Correção adotada |
|---|---|---|---|
| CVE-2026-111497 | brotli-libs | 1.2.0-r0 | 1.2.1-r0 na imagem nova; scan sem a ocorrência |
| CVE-2026-31789 | libcrypto3 | 3.5.5-r0 | 3.5.9-r0 na imagem nova; scan sem a ocorrência |
| CVE-2026-31789 | libssl3 | 3.5.5-r0 | 3.5.9-r0 na imagem nova; scan sem a ocorrência |
| CVE-2026-42945 | nginx | 1.28.2-r1 | Nginx 1.30.6 na imagem corrigida; novo scan sem a ocorrência |

A única alteração no material da aplicação foi o Dockerfile do front: imagem base `nginxinc/nginx-unprivileged:1.30-alpine`, atualização dos pacotes Alpine durante o build e restauração explícita do usuário 101 antes de executar o contêiner. HTML, JavaScript, API e worker não foram modificados. O motivo é corrigir bugs de segurança de dependências, conforme a exceção do enunciado; o commit descreve essa correção.

Validação: `nginx -t` passou com UID 101, filesystem somente leitura, `/tmp` temporário, capabilities removidas e no-new-privileges. Veja `evidencias/front-1.1-runtime.txt` e `evidencias/front-1.1-pacotes.txt`.

Referências primárias: [Alpine — Brotli](https://security.alpinelinux.org/vuln/CVE-2026-111497), [avisos Nginx](https://nginx.org/en/security_advisories.html), [aviso OpenSSL de 07/04/2026](https://openssl-library.org/news/secadv/20260407.txt). As severidades reportadas por Trivy podem diferir das avaliações dos fornecedores e não comprovam explorabilidade na configuração implantada; optamos pela correção dos pacotes.
