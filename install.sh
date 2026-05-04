#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ROOT_DIR="${ROOT_DIR:-/opt/conect-stack}"
REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
N8N_CONTAINER="${N8N_CONTAINER:-conectstack-n8n-1}"

cd /tmp

# ==============================
# 🔥 DEPENDÊNCIAS (À PROVA DE BURRO)
# ==============================
apt update -y >/dev/null 2>&1 || true
apt install -y git jq openssl curl figlet lolcat >/dev/null 2>&1 || true

if ! command -v gum >/dev/null 2>&1; then
  apt install -y curl gnupg >/dev/null 2>&1 || true
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" > /etc/apt/sources.list.d/charm.list
  apt update -y >/dev/null 2>&1
  apt install -y gum >/dev/null 2>&1
fi

# ==============================
# 🎨 UI
# ==============================
clear || true
figlet -f slant "CONECT" | lolcat

gum style \
  --border double \
  --border-foreground 201 \
  --padding "1 3" \
"🚀 CONECT INSTALLER
⚡ UI GALÁXIAS
🔥 1 comando = cliente pronto"

gum spin --spinner globe --title "Inicializando..." -- sleep 1

# ==============================
# 📦 REPO
# ==============================
if [ ! -d "$ROOT_DIR/.git" ]; then
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  git -C "$ROOT_DIR" pull origin main
fi

cd "$ROOT_DIR"

# ==============================
# 📦 TEMPLATE UI
# ==============================
mapfile -t TEMPLATES < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort)

OPTIONS=()

for m in "${TEMPLATES[@]}"; do
  nome=$(jq -r '.nome' "$m")
  desc=$(jq -r '.descricao // ""' "$m")
  OPTIONS+=("$nome — $desc")
done

gum style --foreground 201 --bold "📦 Templates disponíveis"
echo ""

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
ID=$(jq -r '.id' "$MANIFEST")
NAME=$(jq -r '.nome' "$MANIFEST")
WF_DIR="$DIR/workflows"

gum style --foreground 46 --bold "✅ Template: $NAME"

# ==============================
# 📋 CONFIG CLIENTE
# ==============================
EMPRESA=$(gum input --placeholder "Nome do cliente")
CIDADE=$(gum input --placeholder "Cidade")
TEL=$(gum input --placeholder "WhatsApp 55DDD...")
SUPA=$(gum input --placeholder "Supabase URL")

if [ "$ID" = "imobiliaria" ]; then
  SUPA_KEY=$(gum input --password --placeholder "Supabase ANON")
else
  SUPA_KEY=$(gum input --password --placeholder "Supabase SERVICE")
  OPENAI=$(gum input --password --placeholder "OpenAI Key")
fi

gum confirm "Confirmar?" || exit 1

# ==============================
# 🔧 PROCESSO
# ==============================
TMP="/tmp/conect-$ID"
rm -rf "$TMP"
mkdir -p "$TMP"

cp "$WF_DIR"/*.json "$TMP"

gum spin --spinner dot --title "Configurando..." -- sleep 1

sed -i "s|NOME_DO_CLIENTE|$EMPRESA|g" $TMP/*.json
sed -i "s|CIDADE_DO_CLIENTE|$CIDADE|g" $TMP/*.json
sed -i "s|55DDDNUMERO|$TEL|g" $TMP/*.json
sed -i "s|SUA_SUPABASE_URL|$SUPA|g" $TMP/*.json

# ==============================
# 🚀 IMPORTAÇÃO
# ==============================
docker exec "$N8N_CONTAINER" sh -c "rm -rf /tmp/import && mkdir -p /tmp/import"
docker cp "$TMP/." "$N8N_CONTAINER:/tmp/import/"

for f in $TMP/*.json; do
  base=$(basename $f)
  docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/import/$base"
done

# ==============================
# ✅ FINAL
# ==============================
figlet -f slant "PRONTO" | lolcat

gum style \
  --border double \
  --border-foreground 46 \
  --padding "1 3" \
"🔥 CLIENTE CRIADO

📦 $NAME
👤 $EMPRESA
🌐 http://$(curl -s ifconfig.me):5678"

# ==============================
# ⚡ COMANDO UNICO
# ==============================
if [ ! -f /usr/local/bin/conect ]; then
cat > /usr/local/bin/conect <<EOF
#!/bin/bash
cd "$ROOT_DIR"
git pull origin main
bash install.sh
EOF
chmod +x /usr/local/bin/conect
fi