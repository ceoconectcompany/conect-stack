#!/bin/bash
set -euo pipefail

# ========================================
# 🧠 AGUARDAR APT (evita erro de lock)
# ========================================

echo "🔒 Verificando se o apt está ocupado..."

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
   || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
   || fuser /var/cache/apt/archives/lock >/dev/null 2>&1
do
  echo "⏳ Aguardando apt liberar..."
  sleep 3
done

echo "✅ apt liberado, continuando..."

clear || true

echo "========================================"
echo "🚀 CONECT STACK - SETUP MASTER"
echo "========================================"
echo ""

export DEBIAN_FRONTEND=noninteractive

REPO_URL="${REPO_URL:-https://github.com/ceoconectcompany/conect-stack.git}"
ROOT_DIR="${ROOT_DIR:-/opt/conect-kit}"
STACK_DIR="${STACK_DIR:-/opt/conect-stack-runtime}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-conectstack}"
N8N_CONTAINER="${N8N_CONTAINER:-${COMPOSE_PROJECT}-n8n-1}"

need_apt() {
  echo "📦 Instalando dependências base..."
  apt update -y
  apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  apt install -y ca-certificates curl gnupg lsb-release nano openssl git jq ufw
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
  else
    echo "✅ Docker já instalado."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "📦 Instalando Docker Compose plugin..."
    apt install -y docker-compose-plugin
  fi
}

get_ipv4() {
  local ip
  ip=$(curl -4 -s ifconfig.me || true)
  if [ -z "$ip" ]; then
    ip=$(hostname -I | awk '{print $1}')
  fi
  echo "$ip"
}

need_apt
install_docker

IP="$(get_ipv4)"
N8N_USER="${N8N_USER:-admin}"
N8N_PASS="${N8N_PASS:-$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)}"
WAHA_API_KEY="${WAHA_API_KEY:-$(openssl rand -hex 32)}"
WAHA_DASH_USER="${WAHA_DASH_USER:-admin}"
WAHA_DASH_PASS="${WAHA_DASH_PASS:-$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)}"

mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat > docker-compose.yml <<EOF2
services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$N8N_USER
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASS
      - N8N_HOST=$IP
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://$IP:5678/
      - N8N_SECURE_COOKIE=false
      - TZ=America/Campo_Grande
      - GENERIC_TIMEZONE=America/Campo_Grande
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - waha

  waha:
    image: devlikeapro/waha:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - WAHA_API_KEY=$WAHA_API_KEY
      - WAHA_DASHBOARD_USERNAME=$WAHA_DASH_USER
      - WAHA_DASHBOARD_PASSWORD=$WAHA_DASH_PASS
      - WHATSAPP_DEFAULT_ENGINE=WEBJS
      - TZ=America/Campo_Grande
    volumes:
      - waha_sessions:/app/.sessions
      - waha_media:/app/.media

volumes:
  n8n_data:
  waha_sessions:
  waha_media:
EOF2

echo "🚀 Subindo n8n + WAHA..."
docker compose -p "$COMPOSE_PROJECT" up -d

echo "⏳ Aguardando n8n iniciar..."
for i in {1..45}; do
  if docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
    if docker exec "$N8N_CONTAINER" sh -c 'command -v n8n >/dev/null 2>&1' >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 2
done

# Firewall básico sem travar SSH
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow 5678/tcp >/dev/null 2>&1 || true
ufw allow 3000/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

echo "📥 Baixando/atualizando repositório..."
cd /tmp
if [ ! -d "$ROOT_DIR/.git" ]; then
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  git -C "$ROOT_DIR" pull origin main
fi

if [ ! -f "$ROOT_DIR/install.sh" ]; then
  if [ -f "$ROOT_DIR/conect-installer-modular-pronto/install.sh" ]; then
    INSTALL_FILE="$ROOT_DIR/conect-installer-modular-pronto/install.sh"
  else
    echo "❌ Não encontrei install.sh na raiz nem em conect-installer-modular-pronto/install.sh"
    exit 1
  fi
else
  INSTALL_FILE="$ROOT_DIR/install.sh"
fi

chmod +x "$INSTALL_FILE"

cat > "$STACK_DIR/ACESSOS.txt" <<INFO
CONECT STACK - ACESSOS

IPv4: $IP

n8n: http://$IP:5678
n8n user: $N8N_USER
n8n pass: $N8N_PASS

WAHA: http://$IP:3000
WAHA dashboard user: $WAHA_DASH_USER
WAHA dashboard pass: $WAHA_DASH_PASS
WAHA API KEY: $WAHA_API_KEY

Container n8n: $N8N_CONTAINER
Pasta runtime: $STACK_DIR
Pasta repo: $ROOT_DIR
INFO

echo ""
echo "========================================"
echo "✅ STACK BASE ONLINE"
echo "========================================"
echo "🌐 n8n:  http://$IP:5678"
echo "👤 n8n user: $N8N_USER"
echo "🔑 n8n pass: $N8N_PASS"
echo ""
echo "📱 WAHA: http://$IP:3000"
echo "👤 WAHA user: $WAHA_DASH_USER"
echo "🔑 WAHA pass: $WAHA_DASH_PASS"
echo "🔐 WAHA API KEY: $WAHA_API_KEY"
echo ""
echo "📁 Acessos salvos em: $STACK_DIR/ACESSOS.txt"
echo ""
echo "🚀 Agora vamos escolher o template e preencher o CONFIG CLIENTE."
echo ""

export N8N_CONTAINER="$N8N_CONTAINER"
export WAHA_API_KEY="$WAHA_API_KEY"
export WAHA_INTERNAL_URL="http://waha:3000"
export WAHA_EXTERNAL_URL="http://$IP:3000"
export VPS_IPV4="$IP"

bash "$INSTALL_FILE"
