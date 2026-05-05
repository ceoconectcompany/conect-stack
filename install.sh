#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ROOT_DIR="${ROOT_DIR:-/opt/conect-stack}"
REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
N8N_CONTAINER="${N8N_CONTAINER:-conectstack-n8n-1}"

clear

cat <<'EOF'
███████╗███╗   ██╗███████╗ ██████╗     ██████╗ ███████╗██╗   ██╗
██╔════╝████╗  ██║╚══███╔╝██╔═══██╗    ██╔══██╗██╔════╝██║   ██║
█████╗  ██╔██╗ ██║  ███╔╝ ██║   ██║    ██║  ██║█████╗  ██║   ██║
██╔══╝  ██║╚██╗██║ ███╔╝  ██║   ██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝
███████╗██║ ╚████║███████╗╚██████╔╝    ██████╔╝███████╗ ╚████╔╝
╚══════╝╚═╝  ╚═══╝╚══════╝ ╚═════╝     ╚═════╝ ╚══════╝  ╚═══╝

╔════════════════════════════════════╗
║                                    ║
║   🚀 ENZO DEV INSTALLER            ║
║   ⚡ UI GALÁXIAS                   ║
║   🔥 1 comando = cliente pronto    ║
║                                    ║
╚════════════════════════════════════╝
EOF

cd /tmp

echo "📦 Instalando dependências base..."
apt update -y >/dev/null 2>&1 || true
apt install -y git jq openssl curl gnupg ca-certificates figlet >/dev/null 2>&1 || true

if ! command -v gum >/dev/null 2>&1; then
  echo "🎨 Instalando gum..."
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg || true
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" > /etc/apt/sources.list.d/charm.list
  apt update -y >/dev/null 2>&1 || true
  apt install -y gum >/dev/null 2>&1 || true
fi

echo "📥 Atualizando repositório..."
if [ -d "$ROOT_DIR/.git" ]; then
  cd "$ROOT_DIR"
  git pull origin main || true
else
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
  cd "$ROOT_DIR"
fi

if [ ! -d "templates" ]; then
  echo "❌ Pasta templates não encontrada."
  exit 1
fi

# ==============================
# 🧱 GARANTIR MANIFEST DA BASE
# ==============================
mkdir -p templates/base/workflows

if [ ! -f templates/base/manifest.json ]; then
cat > templates/base/manifest.json <<'EOF'
{
  "id": "base",
  "nome": "Base",
  "descricao": "Workflows base de monitoramento WAHA, ping e reset preventivo para criar novos nichos do zero."
}
EOF
fi

# ==============================
# 📦 LISTAR TEMPLATES SEM REPETIR
# ==============================
mapfile -t TEMPLATES < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort -u)

if [ "${#TEMPLATES[@]}" -eq 0 ]; then
  echo "❌ Nenhum manifest.json encontrado dentro de templates."
  exit 1
fi

OPTIONS=()

for m in "${TEMPLATES[@]}"; do
  nome=$(jq -r '.nome' "$m")
  desc=$(jq -r '.descricao // ""' "$m")
  OPTIONS+=("$nome — $desc")
done

gum style --foreground 201 --bold "📦 Templates disponíveis"
echo ""

SELECT=$(printf "%s\n" "${OPTIONS[@]}" | awk '!seen[$0]++' | gum choose --cursor "👉 ")

INDEX=-1
for i in "${!OPTIONS[@]}"; do
  if [ "${OPTIONS[$i]}" = "$SELECT" ]; then
    INDEX=$i
    break
  fi
done

if [ "$INDEX" -lt 0 ]; then
  echo "❌ Nenhum template selecionado."
  exit 1
fi

MANIFEST="${TEMPLATES[$INDEX]}"
DIR="$(dirname "$MANIFEST")"
ID=$(jq -r '.id' "$MANIFEST")
NAME=$(jq -r '.nome' "$MANIFEST")
WF_DIR="$DIR/workflows"

gum style --foreground 82 --bold "✅ Template escolhido: $NAME"
echo ""

CLIENTE=$(gum input --placeholder "Nome do cliente ou projeto")
CIDADE=$(gum input --placeholder "Cidade do cliente ou projeto")
TEL=$(gum input --placeholder "WhatsApp principal. Ex: 556799999999")
SUPA=$(gum input --placeholder "Supabase URL")

if [[ "$ID" == *"imobiliaria"* ]]; then
  SUPA_KEY=$(gum input --password --placeholder "Supabase SERVICE ROLE KEY")
else
  SUPA_KEY=$(gum input --password --placeholder "Supabase ANON/SERVICE KEY")
fi

OPENAI=$(gum input --password --placeholder "OpenAI API KEY")
WAHA_KEY=$(gum input --password --placeholder "WAHA API KEY")

if [ ! -d "$WF_DIR" ]; then
  echo "❌ Pasta de workflows não encontrada: $WF_DIR"
  exit 1
fi

# ==============================
# 🧩 PREPARAR WORKFLOWS
# ==============================
TMP=$(mktemp -d)

echo "📦 Carregando workflows do template: $NAME..."
cp "$WF_DIR"/*.json "$TMP/" 2>/dev/null || true

if ! ls "$TMP"/*.json >/dev/null 2>&1; then
  echo "❌ Nenhum workflow JSON encontrado em: $WF_DIR"
  exit 1
fi

# ==============================
# 🔐 TROCAS DE PLACEHOLDERS
# ==============================
sed -i "s|NOME_DO_CLIENTE|$CLIENTE|g" "$TMP"/*.json
sed -i "s|CIDADE_DO_CLIENTE|$CIDADE|g" "$TMP"/*.json
sed -i "s|55DDDNUMERO|$TEL|g" "$TMP"/*.json
sed -i "s|55DDDNUMEROTESTE|$TEL|g" "$TMP"/*.json
sed -i "s|SUA_SUPABASE_URL|$SUPA|g" "$TMP"/*.json
sed -i "s|SUA_SUPABASE_KEY|$SUPA_KEY|g" "$TMP"/*.json
sed -i "s|SUA_OPENAI_API_KEY|$OPENAI|g" "$TMP"/*.json
sed -i "s|SUA_WAHA_API_KEY|$WAHA_KEY|g" "$TMP"/*.json
sed -i "s|WAHA_API_KEY_AQUI|$WAHA_KEY|g" "$TMP"/*.json
sed -i "s|123456|$WAHA_KEY|g" "$TMP"/*.json

# ==============================
# 🚀 IMPORTAÇÃO
# ==============================
docker exec "$N8N_CONTAINER" sh -c "rm -rf /tmp/import && mkdir -p /tmp/import"
docker cp "$TMP/." "$N8N_CONTAINER:/tmp/import/"

for f in "$TMP"/*.json; do
  base=$(basename "$f")
  echo "📥 Importando: $base"
  docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/import/$base"
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
gum style --foreground 82 --bold "✅ ENZO DEV STACK FINALIZADA COM SUCESSO"
echo ""
echo "📦 Projeto/cliente: $CLIENTE"
echo "🏙️ Cidade: $CIDADE"
echo "📱 WhatsApp: $TEL"
echo "🧩 Template: $NAME"
echo ""
echo "⚡ Para rodar novamente depois:"
echo "enzo"
echo ""
