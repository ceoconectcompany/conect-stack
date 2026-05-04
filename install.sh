#!/bin/bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/opt/conect-kit}"
REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"
WAHA_API_KEY="${WAHA_API_KEY:-$(openssl rand -hex 32)}"
WAHA_INTERNAL_URL="${WAHA_INTERNAL_URL:-http://waha:3000}"
WAHA_EXTERNAL_URL="${WAHA_EXTERNAL_URL:-http://$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}'):3000}"
VPS_IPV4="${VPS_IPV4:-$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')}"

cd /tmp
clear || true

echo "========================================"
echo "🚀 CONECT INSTALLER MODULAR"
echo "📋 CONFIG CLIENTE COMPLETO POR TEMPLATE"
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
need_cmd python3

ask() {
  local var="$1"
  local label="$2"
  local default="${3:-}"
  local secret="${4:-false}"
  local value=""

  if [ "$secret" = "true" ]; then
    if [ -n "$default" ]; then
      read -rsp "$label [ENTER para manter padrão]: " value
    else
      read -rsp "$label: " value
    fi
    echo ""
  else
    if [ -n "$default" ]; then
      read -rp "$label [$default]: " value
    else
      read -rp "$label: " value
    fi
  fi

  if [ -z "$value" ]; then
    value="$default"
  fi

  printf -v "$var" '%s' "$value"
}

ask_bool() {
  local var="$1"
  local label="$2"
  local default="${3:-true}"
  local value=""
  read -rp "$label [$default]: " value
  value="${value:-$default}"
  case "${value,,}" in
    s|sim|y|yes|true|1) printf -v "$var" 'true' ;;
    n|nao|não|no|false|0) printf -v "$var" 'false' ;;
    *) printf -v "$var" '%s' "$default" ;;
  esac
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-'
}

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
  echo "Estrutura esperada: templates/NOME_DO_TEMPLATE/manifest.json + workflows/*.json"
  exit 1
fi

echo ""
echo "📦 Templates disponíveis:"
echo ""
mapfile -t TEMPLATE_MANIFESTS < <(find templates -mindepth 2 -maxdepth 2 -name manifest.json | sort)

if [ "${#TEMPLATE_MANIFESTS[@]}" -eq 0 ]; then
  echo "❌ Nenhum template encontrado."
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
if ! [[ "$escolha" =~ ^[0-9]+$ ]]; then echo "❌ Opção inválida."; exit 1; fi
idx=$((escolha-1))
if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#TEMPLATE_MANIFESTS[@]}" ]; then echo "❌ Opção inválida."; exit 1; fi

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
  echo "❌ Docker não encontrado. Rode o setup.sh master."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
  echo "❌ Container n8n não está rodando com nome '$N8N_CONTAINER'."
  echo "Containers disponíveis:"
  docker ps --format ' - {{.Names}}'
  exit 1
fi

echo ""
echo "========================================"
echo "📋 CONFIG CLIENTE — $TEMPLATE_NOME"
echo "========================================"
echo "Preencha com os dados REAIS do cliente. ENTER mantém o padrão quando existir."
echo ""

# Defaults globais
EMPRESA=""
CLIENTE_ID=""
CIDADE=""
CIDADES_ACEITAS=""
TELEFONE_RESPONSAVEL=""
TELEFONE_CORRETOR=""
TELEFONE_GERENTE=""
NOME_CORRETOR=""
SUPA_URL=""
SUPA_ANON=""
SUPA_SERVICE=""
OPENAI_KEY=""
OPENAI_MODEL="gpt-4o-mini"
SITE_IMOB=""
TELEGRAM_ENZO=""
TELEGRAM_GERENTE=""
TELEGRAM_CORRETOR=""
TELEGRAM_BOT_TOKEN=""
HORARIO_ATENDIMENTO="Segunda a sexta, em horário comercial"
TOM_ATENDIMENTO="humano, consultivo, direto e comercial leve"
MODO_TESTE="true"
NUMERO_TESTE=""

if [ "$TEMPLATE_ID" = "imobiliaria" ]; then
  ask EMPRESA "Nome da imobiliária/empresa" "NOME_DA_IMOBILIARIA"
  DEFAULT_ID="$(slugify "$EMPRESA")"
  ask CLIENTE_ID "cliente_id / slug único" "$DEFAULT_ID"
  ask CIDADE "Cidade principal atendida" "Ponta Porã"
  ask CIDADES_ACEITAS "Cidades aceitas separadas por vírgula" "$CIDADE"
  ask TELEFONE_CORRETOR "WhatsApp do corretor responsável (55DDDNUMERO)" "55DDDNUMERODOCORRETOR"
  ask TELEFONE_GERENTE "WhatsApp do gerente/dono (55DDDNUMERO)" "55DDDNUMERODOGERENTE"
  ask NOME_CORRETOR "Nome do corretor padrão" "Corretor da equipe"
  ask SITE_IMOB "Site da imobiliária" "https://site-da-imobiliaria.com.br"
  ask SUPA_URL "Supabase URL" "https://SEU_PROJECT_REF.supabase.co"
  ask SUPA_ANON "Supabase ANON KEY" "" true
  ask SUPA_SERVICE "Supabase SERVICE_ROLE KEY (opcional, usado se existir placeholder)" "" true
  ask OPENAI_KEY "OpenAI API KEY (opcional; só injeta se o workflow tiver placeholder)" "" true
  ask OPENAI_MODEL "Modelo OpenAI" "gpt-4o-mini"
  ask TELEGRAM_ENZO "Telegram chat ID Enzo/suporte (opcional)" ""
  ask TELEGRAM_GERENTE "Telegram chat ID gerente (opcional)" ""
  ask TELEGRAM_CORRETOR "Telegram chat ID corretor (opcional)" ""
  ask HORARIO_ATENDIMENTO "Horário de atendimento" "$HORARIO_ATENDIMENTO"
  ask_bool MODO_TESTE "Modo teste? true/false" "true"
  ask NUMERO_TESTE "Número de teste (55DDDNUMERO, opcional)" ""
elif [ "$TEMPLATE_ID" = "estetica-automotiva" ]; then
  ask EMPRESA "Nome da empresa/cliente" "NOME_DO_CLIENTE"
  ask CIDADE "Cidade principal" "Ponta Porã"
  ask TELEFONE_RESPONSAVEL "WhatsApp do responsável/dono (55DDDNUMERO)" "55DDDNUMERO"
  ask SUPA_URL "Supabase URL" "https://SEU_PROJECT_REF.supabase.co"
  ask SUPA_SERVICE "Supabase SERVICE_ROLE KEY" "" true
  ask OPENAI_KEY "OpenAI API KEY" "" true
  ask OPENAI_MODEL "Modelo OpenAI" "gpt-4o-mini"
  ask TELEGRAM_BOT_TOKEN "Telegram BOT TOKEN (opcional)" "" true
  ask TELEGRAM_GERENTE "Telegram chat ID dono/gerente (opcional)" ""
  echo ""
  echo "🧼 Serviços da estética automotiva"
  ask SERVICO_1_NOME "Nome do serviço 1" "Limpeza simples"
  ask SERVICO_1_DESC "Descrição do serviço 1" "Limpeza rápida interna e externa"
  ask SERVICO_1_PRECO_NUM "Preço numérico serviço 1. Ex: 80" "80"
  ask SERVICO_1_PRECO_TXT "Preço texto serviço 1. Ex: R$ 80,00" "R$ 80,00"
  ask SERVICO_1_TEMPO "Tempo estimado serviço 1" "1h30"
  ask SERVICO_2_NOME "Nome do serviço 2" "Limpeza detalhada"
  ask SERVICO_2_DESC "Descrição do serviço 2" "Limpeza completa com acabamento detalhado"
  ask SERVICO_2_PRECO_NUM "Preço numérico serviço 2. Ex: 180" "180"
  ask SERVICO_2_PRECO_TXT "Preço texto serviço 2. Ex: R$ 180,00" "R$ 180,00"
  ask SERVICO_2_TEMPO "Tempo estimado serviço 2" "3h"
else
  echo "⚠️ Template sem formulário específico. Usando Config Cliente genérico."
  ask EMPRESA "Nome da empresa/cliente" "NOME_DO_CLIENTE"
  ask CIDADE "Cidade principal" "CIDADE_DO_CLIENTE"
  ask TELEFONE_RESPONSAVEL "WhatsApp responsável (55DDDNUMERO)" "55DDDNUMERO"
  ask SUPA_URL "Supabase URL" "https://SEU_PROJECT_REF.supabase.co"
  ask SUPA_ANON "Supabase ANON KEY (opcional)" "" true
  ask SUPA_SERVICE "Supabase SERVICE_ROLE KEY (opcional)" "" true
  ask OPENAI_KEY "OpenAI API KEY (opcional)" "" true
fi

TMP_HOST="/tmp/conect-template-$TEMPLATE_ID-$$"
rm -rf "$TMP_HOST"
mkdir -p "$TMP_HOST/workflows"
cp "$WORKFLOWS_DIR"/*.json "$TMP_HOST/workflows/"

echo ""
echo "🧩 Aplicando Config Cliente nos workflows..."

REPLACEMENTS_JSON="$TMP_HOST/replacements.json"
python3 - <<PY
import json, os
repl = {
  "NOME_DO_CLIENTE": os.environ.get("EMPRESA", ""),
  "NOME_DA_IMOBILIARIA": os.environ.get("EMPRESA", ""),
  "CLIENTE_IMOBILIARIA_001": os.environ.get("CLIENTE_ID", os.environ.get("EMPRESA", "")),
  "CIDADE_DO_CLIENTE": os.environ.get("CIDADE", ""),
  "CIDADE_ATENDIDA": os.environ.get("CIDADE", ""),
  "CIDADE_SEM_ACENTO": os.environ.get("CIDADE", ""),
  "CIDADE_VIZINHA": os.environ.get("CIDADE", ""),
  "55DDDNUMERO": os.environ.get("TELEFONE_RESPONSAVEL", os.environ.get("TELEFONE_CORRETOR", "")),
  "55DDDNUMERODOCORRETOR": os.environ.get("TELEFONE_CORRETOR", os.environ.get("TELEFONE_RESPONSAVEL", "")),
  "55DDDNUMERODOGERENTE": os.environ.get("TELEFONE_GERENTE", os.environ.get("TELEFONE_RESPONSAVEL", "")),
  "55DDDNUMEROTESTE": os.environ.get("NUMERO_TESTE", os.environ.get("TELEFONE_RESPONSAVEL", "")),
  "SUA_WAHA_API_KEY": os.environ.get("WAHA_API_KEY", ""),
  "SUA_API_KEY_WAHA": os.environ.get("WAHA_API_KEY", ""),
  "http://IP_DA_VPS:3000": os.environ.get("WAHA_EXTERNAL_URL", ""),
  "https://SEU_PROJECT_REF.supabase.co": os.environ.get("SUPA_URL", ""),
  "SUA_SUPABASE_URL": os.environ.get("SUPA_URL", ""),
  "SUA_SUPABASE_SERVICE_ROLE_KEY": os.environ.get("SUPA_SERVICE", ""),
  "SUA_SUPABASE_ANON_KEY": os.environ.get("SUPA_ANON", ""),
  "SUA_OPENAI_API_KEY": os.environ.get("OPENAI_KEY", ""),
  "gpt-4o-mini": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
  "https://site-da-imobiliaria.com.br": os.environ.get("SITE_IMOB", ""),
  "SEU_CHAT_ID_TELEGRAM": os.environ.get("TELEGRAM_ENZO", ""),
  "CHAT_ID_GERENTE": os.environ.get("TELEGRAM_GERENTE", ""),
  "CHAT_ID_CORRETOR": os.environ.get("TELEGRAM_CORRETOR", ""),
  "SEU_TELEGRAM_BOT_TOKEN": os.environ.get("TELEGRAM_BOT_TOKEN", ""),
  "Corretor da equipe": os.environ.get("NOME_CORRETOR", "Corretor da equipe"),
  "Segunda a sexta, em horário comercial": os.environ.get("HORARIO_ATENDIMENTO", "Segunda a sexta, em horário comercial"),
  "SERVIÇO 1": os.environ.get("SERVICO_1_NOME", ""),
  "DESCRIÇÃO DO SERVIÇO 1": os.environ.get("SERVICO_1_DESC", ""),
  "SERVIÇO 2": os.environ.get("SERVICO_2_NOME", ""),
  "DESCRIÇÃO DO SERVIÇO 2": os.environ.get("SERVICO_2_DESC", ""),
  "TEMPO ESTIMADO": os.environ.get("SERVICO_1_TEMPO", ""),
}
# Regras específicas para preços/tempos automotivos são tratadas por troca sequencial abaixo.
with open(os.environ["REPLACEMENTS_JSON"], "w", encoding="utf-8") as f:
    json.dump(repl, f, ensure_ascii=False, indent=2)
PY

export EMPRESA CLIENTE_ID CIDADE CIDADES_ACEITAS TELEFONE_RESPONSAVEL TELEFONE_CORRETOR TELEFONE_GERENTE NOME_CORRETOR SUPA_URL SUPA_ANON SUPA_SERVICE OPENAI_KEY OPENAI_MODEL SITE_IMOB TELEGRAM_ENZO TELEGRAM_GERENTE TELEGRAM_CORRETOR TELEGRAM_BOT_TOKEN HORARIO_ATENDIMENTO MODO_TESTE NUMERO_TESTE WAHA_API_KEY WAHA_INTERNAL_URL WAHA_EXTERNAL_URL REPLACEMENTS_JSON
export SERVICO_1_NOME="${SERVICO_1_NOME:-}" SERVICO_1_DESC="${SERVICO_1_DESC:-}" SERVICO_1_PRECO_NUM="${SERVICO_1_PRECO_NUM:-}" SERVICO_1_PRECO_TXT="${SERVICO_1_PRECO_TXT:-}" SERVICO_1_TEMPO="${SERVICO_1_TEMPO:-}"
export SERVICO_2_NOME="${SERVICO_2_NOME:-}" SERVICO_2_DESC="${SERVICO_2_DESC:-}" SERVICO_2_PRECO_NUM="${SERVICO_2_PRECO_NUM:-}" SERVICO_2_PRECO_TXT="${SERVICO_2_PRECO_TXT:-}" SERVICO_2_TEMPO="${SERVICO_2_TEMPO:-}"

python3 - <<'PY'
import json, os, pathlib, re
root = pathlib.Path(os.environ["TMP_HOST"]) / "workflows"
repl = json.loads(pathlib.Path(os.environ["REPLACEMENTS_JSON"]).read_text(encoding="utf-8"))
# remove replacements vazios para não apagar placeholder opcional sem dado
repl = {k:v for k,v in repl.items() if v is not None and str(v) != ""}

for path in root.glob("*.json"):
    text = path.read_text(encoding="utf-8")
    for k, v in repl.items():
        text = text.replace(k, str(v))

    # Ajustes automotivos mais específicos: preços e tempos em ordem
    if os.environ.get("TEMPLATE_ID") == "estetica-automotiva":
        text = text.replace('preco: 0,', f'preco: {os.environ.get("SERVICO_1_PRECO_NUM","0")},', 1)
        text = text.replace('preco: 0,', f'preco: {os.environ.get("SERVICO_2_PRECO_NUM","0")},', 1)
        text = text.replace('preco_texto: "R$ 0,00"', f'preco_texto: "{os.environ.get("SERVICO_1_PRECO_TXT", "R$ 0,00")}"', 1)
        text = text.replace('preco_texto: "R$ 0,00"', f'preco_texto: "{os.environ.get("SERVICO_2_PRECO_TXT", "R$ 0,00")}"', 1)
        text = text.replace('tempo_texto: "TEMPO ESTIMADO"', f'tempo_texto: "{os.environ.get("SERVICO_1_TEMPO", "")}"', 1)
        text = text.replace('tempo_texto: "TEMPO ESTIMADO"', f'tempo_texto: "{os.environ.get("SERVICO_2_TEMPO", "")}"', 1)

    path.write_text(text, encoding="utf-8")
PY

echo ""
echo "🔎 Validando JSON dos workflows..."
for file in "$TMP_HOST"/workflows/*.json; do
  jq empty "$file" || { echo "❌ JSON inválido: $file"; exit 1; }
done

echo ""
echo "📤 Copiando workflows para o container n8n..."
docker exec "$N8N_CONTAINER" sh -c 'rm -rf /tmp/conect-import && mkdir -p /tmp/conect-import'
docker cp "$TMP_HOST/workflows/." "$N8N_CONTAINER:/tmp/conect-import/"

echo ""
echo "📥 Importando workflows no n8n..."
IMPORT_OK=0
IMPORT_FAIL=0
for file in "$TMP_HOST"/workflows/*.json; do
  base=$(basename "$file")
  echo "➡️  Importando $base"
  if docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/conect-import/$base"; then
    IMPORT_OK=$((IMPORT_OK+1))
  else
    echo "⚠️ Falhou ao importar $base. Veja logs acima."
    IMPORT_FAIL=$((IMPORT_FAIL+1))
  fi
done

REG_DIR="$ROOT_DIR/clientes-instalados"
mkdir -p "$REG_DIR"
SAFE_EMPRESA=$(slugify "$EMPRESA")
REG_FILE="$REG_DIR/${SAFE_EMPRESA}-${TEMPLATE_ID}.txt"

cat > "$REG_FILE" <<INFO
Cliente: $EMPRESA
Template: $TEMPLATE_NOME
Template ID: $TEMPLATE_ID
Cidade: $CIDADE
Cidades aceitas: $CIDADES_ACEITAS
Telefone responsável: ${TELEFONE_RESPONSAVEL:-}
Telefone corretor: ${TELEFONE_CORRETOR:-}
Telefone gerente: ${TELEFONE_GERENTE:-}
WAHA URL interna n8n: $WAHA_INTERNAL_URL
WAHA URL externa: $WAHA_EXTERNAL_URL
WAHA API KEY: $WAHA_API_KEY
Supabase URL: $SUPA_URL
OpenAI Model: $OPENAI_MODEL
Workflows importados OK: $IMPORT_OK
Workflows com falha: $IMPORT_FAIL
Data instalação: $(date -Iseconds)
INFO

rm -rf "$TMP_HOST"

echo ""
echo "========================================"
echo "✅ TEMPLATE INSTALADO COM SUCESSO"
echo "========================================"
echo "Template: $TEMPLATE_NOME"
echo "Cliente: $EMPRESA"
echo "Workflows OK: $IMPORT_OK"
echo "Workflows com falha: $IMPORT_FAIL"
echo ""
echo "🌐 n8n: http://$VPS_IPV4:5678"
echo "📱 WAHA: $WAHA_EXTERNAL_URL"
echo "🔐 WAHA API KEY: $WAHA_API_KEY"
echo "📁 Registro salvo em: $REG_FILE"
echo ""
echo "📌 Próximo passo: abrir o n8n, conferir workflows importados e ativar."
echo "⚠️ Observação: se algum workflow usa node OpenAI com credencial nativa do n8n, talvez ainda precise vincular a credencial no painel. Se o workflow tiver placeholder SUA_OPENAI_API_KEY, ele já foi preenchido."
