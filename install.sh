#!/bin/bash
set -euo pipefail

# ==========================================================
# 🚀 CONECT INSTALLER MODULAR — UI GALÁXIAS EDITION
# ==========================================================

export DEBIAN_FRONTEND=noninteractive

ROOT_DIR="${ROOT_DIR:-/opt/conect-stack}"
REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"

# Evita erro se o script atualizar a própria pasta enquanto você está dentro dela
cd /tmp

# ------------------------------
# 🎨 Dependências de UI
# ------------------------------
install_base_deps() {
  apt update -y >/dev/null 2>&1 || true
  apt install -y git jq openssl curl gum figlet lolcat >/dev/null 2>&1 || true
}

install_base_deps

# ------------------------------
# 🎨 UI helpers
# ------------------------------
ui_header() {
  clear || true
  echo ""
  if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
    figlet -f slant "CONECT" | lolcat
  else
    echo "CONECT"
  fi

  echo ""
  gum style \
    --border double \
    --border-foreground 201 \
    --foreground 15 \
    --padding "1 3" \
"🚀 CONECT INSTALLER MODULAR

⚡ UI GALÁXIAS EDITION
🤖 Templates + Config Cliente
🔥 1 comando = cliente pronto
🧠 n8n + WAHA + Supabase + OpenAI"
  echo ""
}

ui_line() {
  gum style --foreground 240 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

ui_step() {
  echo ""
  ui_line
  gum style --foreground 213 --bold "➜ $1"
  ui_line
  echo ""
}

ui_box() {
  gum style \
    --border rounded \
    --border-foreground 45 \
    --padding "1 2" \
    "$1"
}

ui_neon_box() {
  gum style \
    --border double \
    --border-foreground 201 \
    --foreground 15 \
    --padding "1 2" \
    "$1"
}

ui_success() {
  gum style --foreground 46 --bold "✅ $1"
}

ui_error() {
  gum style --foreground 196 --bold "❌ $1"
}

ui_warn() {
  gum style --foreground 220 --bold "⚠️ $1"
}

ui_info() {
  gum style --foreground 39 --bold "🔎 $1"
}

ui_loading() {
  gum spin --spinner "$1" --title "$2" -- sleep "${3:-1}"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

require_folder() {
  if [ ! -d "$1" ]; then
    ui_error "$2"
    exit 1
  fi
}

ui_header
ui_loading globe "Inicializando módulos visuais..." 1

# ------------------------------
# 📦 Repositório
# ------------------------------
ui_step "Preparando repositório"

if [ ! -d "$ROOT_DIR/.git" ]; then
  ui_info "Clonando repositório em $ROOT_DIR..."
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  ui_info "Atualizando repositório..."
  git -C "$ROOT_DIR" pull origin main
fi

cd "$ROOT_DIR"

if [ ! -d "templates" ]; then
  ui_error "Pasta templates/ não encontrada."
  ui_box "Estrutura esperada:

templates/
  imobiliaria/
    manifest.json
    workflows/
      01-atendimento.json

templates/
  estetica-automotiva/
    manifest.json
    workflows/
      01-atendimento.json"
  exit 1
fi

# ------------------------------
# 📦 Escolha de template
# ------------------------------
ui_step "Templates disponíveis"

mapfile -t TEMPLATE_MANIFESTS < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort)

if [ "${#TEMPLATE_MANIFESTS[@]}" -eq 0 ]; then
  ui_error "Nenhum template encontrado."
  ui_box "Cada template precisa ter:

templates/NOME_DO_TEMPLATE/manifest.json"
  exit 1
fi

DISPLAY_OPTIONS=()
for manifest in "${TEMPLATE_MANIFESTS[@]}"; do
  id=$(jq -r '.id // input_filename | split("/")[-2]' "$manifest")
  nome=$(jq -r '.nome // .id // input_filename' "$manifest")
  desc=$(jq -r '.descricao // ""' "$manifest")

  emoji="🧩"
  case "$id" in
    imobiliaria) emoji="🏠" ;;
    estetica-automotiva) emoji="🚗" ;;
    delivery) emoji="🍔" ;;
    dentista) emoji="🦷" ;;
  esac

  DISPLAY_OPTIONS+=("$emoji $nome — $desc")
done

ui_neon_box "📦 Escolha com ↑ ↓ e ENTER

${DISPLAY_OPTIONS[*]}"

echo ""
TEMPLATE_ESCOLHIDO=$(printf "%s\n" "${DISPLAY_OPTIONS[@]}" | gum choose --height 10 --cursor.foreground 201 --selected.foreground 46)

if [ -z "$TEMPLATE_ESCOLHIDO" ]; then
  ui_error "Nenhum template selecionado."
  exit 1
fi

SELECTED_INDEX=-1
for i in "${!DISPLAY_OPTIONS[@]}"; do
  if [ "${DISPLAY_OPTIONS[$i]}" = "$TEMPLATE_ESCOLHIDO" ]; then
    SELECTED_INDEX="$i"
    break
  fi
done

if [ "$SELECTED_INDEX" -lt 0 ]; then
  ui_error "Falha ao identificar template selecionado."
  exit 1
fi

MANIFEST="${TEMPLATE_MANIFESTS[$SELECTED_INDEX]}"
TEMPLATE_DIR="$(dirname "$MANIFEST")"
TEMPLATE_ID=$(jq -r '.id // input_filename | split("/")[-2]' "$MANIFEST")
TEMPLATE_NOME=$(jq -r '.nome // .id' "$MANIFEST")
TEMPLATE_DESC=$(jq -r '.descricao // ""' "$MANIFEST")
WORKFLOWS_SUBDIR=$(jq -r '.workflows_dir // "workflows"' "$MANIFEST")
WORKFLOWS_DIR="$TEMPLATE_DIR/$WORKFLOWS_SUBDIR"

require_folder "$WORKFLOWS_DIR" "Pasta de workflows não encontrada: $WORKFLOWS_DIR"

ui_success "Template selecionado: $TEMPLATE_NOME"
[ -n "$TEMPLATE_DESC" ] && ui_box "$TEMPLATE_DESC"

# ------------------------------
# 🐳 Checagens Docker/n8n
# ------------------------------
ui_step "Validando ambiente"

if ! command -v docker >/dev/null 2>&1; then
  ui_error "Docker não encontrado."
  ui_box "Rode primeiro o setup da stack com Docker, n8n e WAHA."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
  ui_error "Container n8n não está rodando com nome '$N8N_CONTAINER'."
  ui_box "Veja os containers com:

docker ps

Se o nome for diferente, rode assim:

N8N_CONTAINER=nome_do_container bash install.sh"
  exit 1
fi

IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')
WAHA_API_KEY="${WAHA_API_KEY:-$(openssl rand -hex 32)}"

ui_success "Docker OK"
ui_success "n8n container OK: $N8N_CONTAINER"
ui_success "IP detectado: $IP"

# ------------------------------
# 📋 Config Cliente
# ------------------------------
ui_step "Config Cliente — $TEMPLATE_NOME"

ui_neon_box "Preencha os dados reais do cliente.

Campos sensíveis aparecem escondidos.
No final você confirma tudo antes de importar."

EMPRESA=$(gum input --placeholder "Nome da empresa / cliente")
CIDADE=$(gum input --placeholder "Cidade principal atendida")
TELEFONE=$(gum input --placeholder "Telefone responsável/corretor. Ex: 556799999999")
SUPA_URL=$(gum input --placeholder "Supabase URL. Ex: https://xxxxx.supabase.co")

SUPA_SERVICE=""
SUPA_ANON=""
OPENAI_KEY=""
SITE_IMOB=""
TELEGRAM_GERENTE=""
TELEGRAM_CORRETOR=""

if [ "$TEMPLATE_ID" = "imobiliaria" ]; then
  SUPA_ANON=$(gum input --password --placeholder "Supabase ANON KEY")
  SITE_IMOB=$(gum input --placeholder "Site da imobiliária. Ex: https://site.com.br")
  TELEGRAM_GERENTE=$(gum input --placeholder "Telegram gerente/chat id (opcional)")
  TELEGRAM_CORRETOR=$(gum input --placeholder "Telegram corretor/chat id (opcional)")
else
  SUPA_SERVICE=$(gum input --password --placeholder "Supabase SERVICE_ROLE KEY")
  OPENAI_KEY=$(gum input --password --placeholder "OpenAI API KEY")
fi

echo ""
gum style \
  --border double \
  --border-foreground 99 \
  --padding "1 2" \
"👤 Cliente: $EMPRESA
🏙️ Cidade: $CIDADE
📦 Template: $TEMPLATE_NOME
📱 Telefone: $TELEFONE
🌐 VPS: http://$IP
📡 WAHA: http://$IP:3000
🗄️ Supabase: configurado
🔐 Chaves sensíveis: protegidas"

echo ""
gum confirm "🔥 Confirmar e continuar com a instalação?" || {
  ui_warn "Instalação cancelada pelo usuário."
  exit 0
}

# ------------------------------
# 🧩 Aplicação dos dados nos workflows
# ------------------------------
ui_step "Aplicando Config Cliente nos workflows"

TMP_HOST="/tmp/conect-template-$TEMPLATE_ID-$$"
rm -rf "$TMP_HOST"
mkdir -p "$TMP_HOST/workflows"

cp "$WORKFLOWS_DIR"/*.json "$TMP_HOST/workflows/"

EMPRESA_ESC=$(sed_escape "$EMPRESA")
CIDADE_ESC=$(sed_escape "$CIDADE")
TELEFONE_ESC=$(sed_escape "$TELEFONE")
WAHA_ESC=$(sed_escape "$WAHA_API_KEY")
IP_ESC=$(sed_escape "$IP")
SUPA_URL_ESC=$(sed_escape "$SUPA_URL")
SUPA_SERVICE_ESC=$(sed_escape "$SUPA_SERVICE")
SUPA_ANON_ESC=$(sed_escape "$SUPA_ANON")
OPENAI_ESC=$(sed_escape "$OPENAI_KEY")
SITE_IMOB_ESC=$(sed_escape "$SITE_IMOB")
TELEGRAM_GERENTE_ESC=$(sed_escape "$TELEGRAM_GERENTE")
TELEGRAM_CORRETOR_ESC=$(sed_escape "$TELEGRAM_CORRETOR")

ui_loading dot "Personalizando workflows..." 1

find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
  -e "s|NOME_DO_CLIENTE|$EMPRESA_ESC|g" \
  -e "s|NOME_DA_IMOBILIARIA|$EMPRESA_ESC|g" \
  -e "s|CLIENTE_IMOBILIARIA_001|$EMPRESA_ESC|g" \
  -e "s|CIDADE_DO_CLIENTE|$CIDADE_ESC|g" \
  -e "s|CIDADE_ATENDIDA|$CIDADE_ESC|g" \
  -e "s|55DDDNUMERO|$TELEFONE_ESC|g" \
  -e "s|55DDDNUMERODOCORRETOR|$TELEFONE_ESC|g" \
  -e "s|SUA_WAHA_API_KEY|$WAHA_ESC|g" \
  -e "s|SUA_API_KEY_WAHA|$WAHA_ESC|g" \
  -e "s|http://IP_DA_VPS:3000|http://$IP_ESC:3000|g" \
  -e "s|https://SEU_PROJECT_REF.supabase.co|$SUPA_URL_ESC|g" \
  -e "s|SUA_SUPABASE_URL|$SUPA_URL_ESC|g"

if [ -n "$SUPA_SERVICE" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_SUPABASE_SERVICE_ROLE_KEY|$SUPA_SERVICE_ESC|g"
fi

if [ -n "$SUPA_ANON" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_SUPABASE_ANON_KEY|$SUPA_ANON_ESC|g"
fi

if [ -n "$OPENAI_KEY" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|SUA_OPENAI_API_KEY|$OPENAI_ESC|g"
fi

if [ -n "$SITE_IMOB" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|https://site-da-imobiliaria.com.br|$SITE_IMOB_ESC|g"
fi

if [ -n "$TELEGRAM_GERENTE" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|CHAT_ID_GERENTE|$TELEGRAM_GERENTE_ESC|g"
fi

if [ -n "$TELEGRAM_CORRETOR" ]; then
  find "$TMP_HOST/workflows" -type f -name '*.json' -print0 | xargs -0 sed -i \
    -e "s|CHAT_ID_CORRETOR|$TELEGRAM_CORRETOR_ESC|g"
fi

ui_success "Config aplicada nos workflows"

# ------------------------------
# 🔎 Validação JSON
# ------------------------------
ui_step "Validando JSON"

for file in "$TMP_HOST"/workflows/*.json; do
  jq empty "$file" || {
    ui_error "JSON inválido: $file"
    exit 1
  }
done

ui_success "Todos os JSON estão válidos"

# ------------------------------
# 📤 Copiar/importar workflows
# ------------------------------
ui_step "Importando no n8n"

ui_loading line "Preparando container n8n..." 1

docker exec "$N8N_CONTAINER" sh -c 'rm -rf /tmp/conect-import && mkdir -p /tmp/conect-import'
docker cp "$TMP_HOST/workflows/." "$N8N_CONTAINER:/tmp/conect-import/"

IMPORTADOS=0
FALHAS=0

for file in "$TMP_HOST"/workflows/*.json; do
  base=$(basename "$file")
  echo ""
  gum style --foreground 39 --bold "➡️ Importando $base"

  if docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/conect-import/$base"; then
    IMPORTADOS=$((IMPORTADOS+1))
    ui_success "$base importado"
  else
    FALHAS=$((FALHAS+1))
    ui_warn "Falhou ao importar $base. Veja logs acima."
  fi
done

# ------------------------------
# 🧾 Registro do cliente
# ------------------------------
cat > "$TMP_HOST/CLIENTE-INSTALADO.txt" <<INFO
Cliente: $EMPRESA
Template: $TEMPLATE_NOME
Cidade: $CIDADE
Telefone responsável: $TELEFONE
WAHA URL externa: http://$IP:3000
WAHA API KEY: $WAHA_API_KEY
Supabase URL: $SUPA_URL
Workflows importados: $IMPORTADOS
Falhas de importação: $FALHAS
INFO

mkdir -p "$ROOT_DIR/clientes-instalados"

SAFE_EMPRESA=$(echo "$EMPRESA" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')
REGISTRO="$ROOT_DIR/clientes-instalados/${SAFE_EMPRESA}-${TEMPLATE_ID}.txt"

cp "$TMP_HOST/CLIENTE-INSTALADO.txt" "$REGISTRO"
rm -rf "$TMP_HOST"

# ------------------------------
# ✅ Final
# ------------------------------
ui_step "Instalação concluída"

if [ "$FALHAS" -eq 0 ]; then
  STATUS_FINAL="🔥 CLIENTE CRIADO COM SUCESSO 🔥"
else
  STATUS_FINAL="⚠️ CLIENTE CRIADO COM ALERTAS ⚠️"
fi

if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
  figlet -f slant "PRONTO" | lolcat
fi

gum style \
  --border double \
  --border-foreground 46 \
  --foreground 15 \
  --padding "1 3" \
"$STATUS_FINAL

📦 Template: $TEMPLATE_NOME
👤 Cliente: $EMPRESA
🏙️ Cidade: $CIDADE

✅ Workflows importados: $IMPORTADOS
⚠️ Falhas: $FALHAS

🌐 n8n:
http://$IP:5678

📱 WAHA:
http://$IP:3000

🔐 WAHA API KEY:
$WAHA_API_KEY

📁 Registro:
$REGISTRO"

echo ""
gum style --foreground 220 --bold "📌 Próximo passo: abrir o n8n, conferir os workflows importados e ativar."
echo ""

# ------------------------------
# ⚡ Comando único conect
# ------------------------------
if [ ! -f /usr/local/bin/conect ]; then
  cat > /usr/local/bin/conect <<EOF
#!/bin/bash
set -e
cd "$ROOT_DIR"
git pull origin main
bash install.sh
EOF
  chmod +x /usr/local/bin/conect
  ui_success "Comando único criado: conect"
fi
