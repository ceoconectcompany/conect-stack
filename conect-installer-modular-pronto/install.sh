#!/bin/bash
set -euo pipefail

ROOT_DIR="/opt/conect-kit"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"

# Evita erro se o script apagar/atualizar a própria pasta enquanto você está dentro dela
cd /tmp

clear || true
echo "========================================"
echo "🚀 CONECT INSTALLER MODULAR"
echo "========================================"
echo ""

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "📦 Instalando dependência: $1"
    apt update -y >/dev/null
    apt install -y "$1" >/dev/null
  fi
}

need_cmd git
need_cmd jq
need_cmd openssl
need_cmd curl

echo "🔎 Preparando repositório..."

if [ ! -d "$ROOT_DIR/.git" ]; then
  echo "📥 Clonando repositório em $ROOT_DIR..."
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  echo "🔄 Atualizando repositório..."
  git -C "$ROOT_DIR" pull origin main
fi

cd "$ROOT_DIR"

if [ ! -d "templates" ]; then
  echo "❌ Pasta templates/ não encontrada."
  echo "Verifique se o repo tem: templates/NOME_DO_TEMPLATE/manifest.json"
  exit 1
fi

echo ""
echo "📦 Templates disponíveis:"
echo ""

mapfile -t TEMPLATE_MANIFESTS < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort)

if [ "${#TEMPLATE_MANIFESTS[@]}" -eq 0 ]; then
  echo "❌ Nenhum template encontrado."
  echo "Cada template precisa ter: templates/NOME/manifest.json"
  exit 1
fi

for i in "${!TEMPLATE_MANIFESTS[@]}"; do
  manifest="${TEMPLATE_MANIFESTS[$i]}"
  nome=$(jq -r '.nome // .id' "$manifest")
  desc=$(jq -r '.descricao // ""' "$manifest")
  printf "%s) %s\n" "$((i+1))" "$nome"
  [ -n "$desc" ] && [ "$desc" != "null" ] && printf "   %s\n" "$desc"
done

echo ""
read -rp "👉 Escolha o template: " escolha

if ! [[ "$escolha" =~ ^[0-9]+$ ]]; then
  echo "❌ Opção inválida."
  exit 1
fi

idx=$((escolha-1))

if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#TEMPLATE_MANIFESTS[@]}" ]; then
  echo "❌ Opção inválida."
  exit 1
fi

MANIFEST="${TEMPLATE_MANIFESTS[$idx]}"
TEMPLATE_DIR="$(dirname "$MANIFEST")"
TEMPLATE_ID=$(jq -r '.id' "$MANIFEST")
TEMPLATE_NOME=$(jq -r '.nome' "$MANIFEST")
WORKFLOWS_SUBDIR=$(jq -r '.workflows_dir // "workflows"' "$MANIFEST")
WORKFLOWS_DIR="$TEMPLATE_DIR/$WORKFLOWS_SUBDIR"

if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo "❌ Pasta de workflows não encontrada: $WORKFLOWS_DIR"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker não encontrado."
  echo "Rode primeiro o setup da stack com Docker, n8n e WAHA."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
  echo "❌ Container n8n não está rodando com nome '$N8N_CONTAINER'."
  echo "Veja com:"
  echo "docker ps"
  exit 1
fi

IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')
WAHA_API_KEY="${WAHA_API_KEY:-$(openssl rand -hex 32)}"

echo ""
echo "========================================"
echo "📋 CONFIG CLIENTE — $TEMPLATE_NOME"
echo "========================================"

read -rp "Nome da empresa/cliente: " EMPRESA
read -rp "Cidade principal: " CIDADE
read -rp "Telefone responsável/corretor (55DDDNUMERO): " TELEFONE
read -rp "Supabase URL: " SUPA_URL

SUPA_SERVICE=""
SUPA_ANON=""
OPENAI_KEY=""
SITE_IMOB=""
TELEGRAM_GERENTE=""
TELEGRAM_CORRETOR=""

if [ "$TEMPLATE_ID" = "imobiliaria" ]; then
  read -rp "Supabase ANON KEY: " SUPA_ANON
  read -rp "Site da imobiliária: " SITE_IMOB
  read -rp "Telegram gerente/chat id (opcional): " TELEGRAM_GERENTE
  read -rp "Telegram corretor/chat id (opcional): " TELEGRAM_CORRETOR
else
  read -rp "Supabase SERVICE_ROLE KEY: " SUPA_SERVICE
  read -rp "OpenAI API KEY: " OPENAI_KEY
fi

TMP_HOST="/tmp/conect-template-$TEMPLATE_ID-$$"

rm -rf "$TMP_HOST"
mkdir -p "$TMP_HOST/workflows"

cp "$WORKFLOWS_DIR"/*.json "$TMP_HOST/workflows/"

echo ""
echo "🧩 Aplicando Config Cliente nos workflows..."

find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
  -e "s|NOME_DO_CLIENTE|$EMPRESA|g" \
  -e "s|NOME_DA_IMOBILIARIA|$EMPRESA|g" \
  -e "s|CLIENTE_IMOBILIARIA_001|$EMPRESA|g" \
  -e "s|CIDADE_DO_CLIENTE|$CIDADE|g" \
  -e "s|CIDADE_ATENDIDA|$CIDADE|g" \
  -e "s|55DDDNUMERO|$TELEFONE|g" \
  -e "s|55DDDNUMERODOCORRETOR|$TELEFONE|g" \
  -e "s|SUA_WAHA_API_KEY|$WAHA_API_KEY|g" \
  -e "s|SUA_API_KEY_WAHA|$WAHA_API_KEY|g" \
  -e "s|http://IP_DA_VPS:3000|http://$IP:3000|g" \
  -e "s|https://SEU_PROJECT_REF.supabase.co|$SUPA_URL|g" \
  -e "s|SUA_SUPABASE_URL|$SUPA_URL|g"

if [ -n "$SUPA_SERVICE" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_SUPABASE_SERVICE_ROLE_KEY|$SUPA_SERVICE|g"
fi

if [ -n "$SUPA_ANON" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_SUPABASE_ANON_KEY|$SUPA_ANON|g"
fi

if [ -n "$OPENAI_KEY" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_OPENAI_API_KEY|$OPENAI_KEY|g"
fi

if [ -n "$SITE_IMOB" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|https://site-da-imobiliaria.com.br|$SITE_IMOB|g"
fi

if [ -n "$TELEGRAM_GERENTE" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|CHAT_ID_GERENTE|$TELEGRAM_GERENTE|g"
fi

if [ -n "$TELEGRAM_CORRETOR" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|CHAT_ID_CORRETOR|$TELEGRAM_CORRETOR|g"
fi

echo ""
echo "🔎 Validando JSON dos workflows..."

for file in "$TMP_HOST"/workflows/*.json; do
  jq empty "$file" || {
    echo "❌ JSON inválido: $file"
    exit 1
  }
done

echo ""
echo "📤 Copiando workflows para o container n8n..."

docker exec "$N8N_CONTAINER" sh -c 'rm -rf /tmp/conect-import && mkdir -p /tmp/conect-import'
docker cp "$TMP_HOST/workflows/." "$N8N_CONTAINER:/tmp/conect-import/"

echo ""
echo "📥 Importando workflows no n8n..."

for file in "$TMP_HOST"/workflows/*.json; do
  base=$(basename "$file")
  echo "➡️  Importando $base"

  docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/conect-import/$base" || {
    echo "⚠️ Falhou ao importar $base. Veja logs acima."
  }
done

cat > "$TMP_HOST/CLIENTE-INSTALADO.txt" <<INFO
Cliente: $EMPRESA
Template: $TEMPLATE_NOME
Cidade: $CIDADE
Telefone responsável: $TELEFONE
WAHA URL externa: http://$IP:3000
WAHA API KEY: $WAHA_API_KEY
Supabase URL: $SUPA_URL
INFO

mkdir -p "$ROOT_DIR/clientes-instalados"

SAFE_EMPRESA=$(echo "$EMPRESA" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')
cp "$TMP_HOST/CLIENTE-INSTALADO.txt" "$ROOT_DIR/clientes-instalados/${SAFE_EMPRESA}-${TEMPLATE_ID}.txt"

rm -rf "$TMP_HOST"

echo ""
echo "========================================"
echo "✅ TEMPLATE INSTALADO COM SUCESSO"
echo "========================================"
echo "Template: $TEMPLATE_NOME"
echo "Cliente: $EMPRESA"
echo ""
echo "🌐 n8n:"
echo "http://$IP:5678"
echo ""
echo "📱 WAHA:"
echo "http://$IP:3000"
echo ""
echo "🔐 WAHA API KEY:"
echo "$WAHA_API_KEY"
echo ""
echo "📁 Registro salvo em:"
echo "$ROOT_DIR/clientes-instalados/${SAFE_EMPRESA}-${TEMPLATE_ID}.txt"
echo ""
echo "📌 Próximo passo: abrir o n8n, conferir os workflows importados e ativar."