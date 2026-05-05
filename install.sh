#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ROOT_DIR="${ROOT_DIR:-/opt/conect-stack}"
REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
N8N_CONTAINER="${N8N_CONTAINER:-conect-stack-n8n-1}"

clear

echo "🚀 ENZO DEV INSTALLER PRO"

cd /tmp

echo "📦 Instalando dependências base..."
apt update -y >/dev/null 2>&1 || true
apt install -y git jq openssl curl gnupg ca-certificates figlet python3 >/dev/null 2>&1 || true

# ==============================
# 🎨 GUM (UI)
# ==============================
if ! command -v gum >/dev/null 2>&1; then
  echo "🎨 Instalando gum..."
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg || true
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" > /etc/apt/sources.list.d/charm.list
  apt update -y >/dev/null 2>&1 || true
  apt install -y gum >/dev/null 2>&1 || true
fi

# ==============================
# 📥 REPO
# ==============================
echo "📥 Atualizando repositório..."

if [ -d "$ROOT_DIR/.git" ]; then
  cd "$ROOT_DIR"
  git pull origin main || true
else
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
  cd "$ROOT_DIR"
fi

# ==============================
# 📦 TEMPLATES
# ==============================
mapfile -t TEMPLATES < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort -u)

OPTIONS=()
for m in "${TEMPLATES[@]}"; do
  nome=$(jq -r '.nome' "$m")
  desc=$(jq -r '.descricao // ""' "$m")
  OPTIONS+=("$nome — $desc")
done

gum style --foreground 201 --bold "📦 Templates disponíveis"

SELECT=$(printf "%s\n" "${OPTIONS[@]}" | gum choose --cursor "👉 ")

INDEX=-1
for i in "${!OPTIONS[@]}"; do
  if [ "${OPTIONS[$i]}" = "$SELECT" ]; then
    INDEX=$i
    break
  fi
done

MANIFEST="${TEMPLATES[$INDEX]}"
DIR="$(dirname "$MANIFEST")"
NAME=$(jq -r '.nome' "$MANIFEST")
WF_DIR="$DIR/workflows"

gum style --foreground 82 --bold "✅ Template: $NAME"

# ==============================
# 🔧 INPUTS
# ==============================
CLIENTE=$(gum input --placeholder "Nome do cliente")
WAHA_KEY=$(gum input --password --placeholder "WAHA API KEY")
TELEGRAM_TOKEN=$(gum input --password --placeholder "Telegram BOT TOKEN")
TELEGRAM_CHAT=$(gum input --placeholder "Telegram CHAT ID")

# ==============================
# 📦 PREPARAR
# ==============================
TMP=$(mktemp -d)
cp "$WF_DIR"/*.json "$TMP/"

# ==============================
# 🔐 INJETAR CONFIG
# ==============================
sed -i "s|NOME_DO_CLIENTE|$CLIENTE|g" "$TMP"/*.json
sed -i "s|SUA_WAHA_API_KEY|$WAHA_KEY|g" "$TMP"/*.json
sed -i "s|SEU_BOT_TOKEN_TELEGRAM|$TELEGRAM_TOKEN|g" "$TMP"/*.json
sed -i "s|SEU_CHAT_ID_TELEGRAM|$TELEGRAM_CHAT|g" "$TMP"/*.json

# ==============================
# 🧪 VALIDAR + CORRIGIR
# ==============================
echo "🧪 Validando workflows..."

for f in "$TMP"/*.json; do
  echo "👉 $(basename "$f")"

  if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "❌ JSON inválido: $f"
    continue
  fi

  HAS_ID=$(jq 'has("id")' "$f")

  if [ "$HAS_ID" != "true" ]; then
    echo "⚠️ Corrigindo ID..."

    WF_ID=$(basename "$f" .json | sed 's|[^a-zA-Z0-9_-]|_|g')

    jq --arg id "$WF_ID" '. + {id: $id}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
done

# ==============================
# 🚀 IMPORT
# ==============================
echo "📥 Importando..."

docker exec "$N8N_CONTAINER" sh -c "rm -rf /tmp/import && mkdir -p /tmp/import"
docker cp "$TMP/." "$N8N_CONTAINER:/tmp/import/"

for f in "$TMP"/*.json; do
  base=$(basename "$f")

  echo "📥 $base"

  if docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/import/$base"; then
    echo "✅ OK"
  else
    echo "❌ ERRO (ignorado)"
  fi
done

# ==============================
# ⚡ COMANDO GLOBAL
# ==============================
cat > /usr/local/bin/enzo <<EOF
#!/bin/bash
cd "$ROOT_DIR"
git pull origin main
bash install.sh
EOF

chmod +x /usr/local/bin/enzo

echo ""
gum style --foreground 82 --bold "🔥 INSTALAÇÃO FINALIZADA"
echo ""
echo "Cliente: $CLIENTE"
echo ""
echo "Rodar novamente: enzo"
echo ""
