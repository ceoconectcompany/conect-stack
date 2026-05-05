#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

APP_DIR="/opt/conect-stack"
PROJECT_NAME="conect-stack"

clear || true

banner() {
  echo "=================================================="
  echo "███████╗███╗   ██╗███████╗ ██████╗     ██████╗ ███████╗██╗   ██╗"
  echo "██╔════╝████╗  ██║╚══███╔╝██╔═══██╗    ██╔══██╗██╔════╝██║   ██║"
  echo "█████╗  ██╔██╗ ██║  ███╔╝ ██║   ██║    ██║  ██║█████╗  ██║   ██║"
  echo "██╔══╝  ██║╚██╗██║ ███╔╝  ██║   ██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝"
  echo "███████╗██║ ╚████║███████╗╚██████╔╝    ██████╔╝███████╗ ╚████╔╝"
  echo "╚══════╝╚═╝  ╚═══╝╚══════╝ ╚═════╝     ╚═════╝ ╚══════╝  ╚═══╝"
  echo "=================================================="
  echo "🔥 CONECT STACK INSTALLER — ENZO DEV 🔥"
  echo "=================================================="
  echo ""
}

matrix_loader() {
  local msg="$1"
  local pid="$2"

  clear || true
  echo "🔥 ENZO DEV — ${msg} 🔥"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  while kill -0 "$pid" >/dev/null 2>&1; do
    for i in {1..22}; do
      echo "$(openssl rand -hex 24) | $(date +%H:%M:%S) | CONECT_STACK | WAHA | N8N | DOCKER | ENZO_DEV"
    done
    sleep 0.08
    clear || true
    echo "🔥 ENZO DEV — ${msg} 🔥"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  done

  wait "$pid"
}

run_with_matrix() {
  local msg="$1"
  local logfile="$2"
  shift 2

  (
    "$@"
  ) >"$logfile" 2>&1 &

  local pid="$!"

  if ! matrix_loader "$msg" "$pid"; then
    clear || true
    banner
    echo "❌ ERRO DURANTE: $msg"
    echo ""
    echo "📄 LOG:"
    cat "$logfile"
    exit 1
  fi
}

step() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚀 $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

ok() {
  echo "✅ $1"
}

warn() {
  echo "⚠️  $1"
}

banner

step "Preparando servidor"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

ok "Diretório preparado em $APP_DIR"

step "Liberando APT"

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
      fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
      fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  warn "APT ocupado. Aguardando liberar..."
  sleep 5
done

ok "APT liberado"

run_with_matrix "ATUALIZANDO PACOTES" "/tmp/conect-apt-update.log" \
  apt update -y

run_with_matrix "INSTALANDO DEPENDÊNCIAS" "/tmp/conect-deps.log" \
  apt install -y ca-certificates curl gnupg lsb-release nano openssl git jq

clear || true
banner
ok "Dependências instaladas"

step "Instalando Docker"

if ! command -v docker >/dev/null 2>&1; then
  run_with_matrix "INSTALANDO DOCKER" "/tmp/conect-docker.log" \
    sh -c "curl -fsSL https://get.docker.com | sh"
  ok "Docker instalado"
else
  ok "Docker já estava instalado"
fi

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker >/dev/null 2>&1 || true

run_with_matrix "INSTALANDO DOCKER COMPOSE" "/tmp/conect-compose.log" \
  apt install -y docker-compose-plugin

clear || true
banner
ok "Docker Compose Plugin instalado"

step "Gerando credenciais automáticas"

WAHA_API_KEY="$(openssl rand -hex 32)"
WAHA_USER="admin"
WAHA_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)"

N8N_USER="admin"
N8N_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)"

ok "Credenciais geradas"

step "Criando docker-compose.yml"

cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - GENERIC_TIMEZONE=America/Asuncion
      - TZ=America/Asuncion
      - N8N_SECURE_COOKIE=false
    volumes:
      - n8n_data:/home/node/.n8n

  waha:
    image: devlikeapro/waha:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - WAHA_API_KEY=${WAHA_API_KEY}
      - WAHA_DASHBOARD_USERNAME=${WAHA_USER}
      - WAHA_DASHBOARD_PASSWORD=${WAHA_PASSWORD}
      - TZ=America/Asuncion

volumes:
  n8n_data:
EOF

ok "docker-compose.yml criado"

run_with_matrix "BAIXANDO IMAGENS DOCKER" "/tmp/conect-docker-pull.log" \
  docker compose -p "$PROJECT_NAME" pull

run_with_matrix "SUBINDO CONECT STACK" "/tmp/conect-stack-up.log" \
  docker compose -p "$PROJECT_NAME" up -d

clear || true
banner
ok "Containers iniciados"

step "Aguardando serviços ficarem online"

sleep 8

for i in {1..30}; do
  if curl -fsS http://localhost:5678 >/dev/null 2>&1; then
    ok "n8n online"
    break
  fi

  if [ "$i" -eq 30 ]; then
    warn "n8n ainda não respondeu, mas o container pode estar iniciando"
  fi

  sleep 3
done

for i in {1..30}; do
  if curl -fsS http://localhost:3000 >/dev/null 2>&1; then
    ok "WAHA online"
    break
  fi

  if [ "$i" -eq 30 ]; then
    warn "WAHA ainda não respondeu, mas o container pode estar iniciando"
  fi

  sleep 3
done

step "Coletando IPv4 público"

IPV4="$(curl -4 -fsSL https://api.ipify.org || true)"

if [ -z "$IPV4" ]; then
  IPV4="$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /:/) {print $i; exit}}')"
fi

if [ -z "$IPV4" ]; then
  IPV4="SEU_IP_V4_DA_VPS"
fi

clear || true
banner

echo "🔥 CONECT STACK INSTALADA COM SUCESSO 🔥"
echo ""
echo "🌐 n8n:"
echo "http://${IPV4}:5678"
echo ""
echo "🌐 WAHA:"
echo "http://${IPV4}:3000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 ACESSO N8N"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 Login:    ${N8N_USER}"
echo "🔑 Password: ${N8N_PASSWORD}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 ACESSO WAHA DASHBOARD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 Login:    ${WAHA_USER}"
echo "🔑 Password: ${WAHA_PASSWORD}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 WAHA API KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${WAHA_API_KEY}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 CONTAINERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "✅ Finalizado por ENZO DEV"
echo "=================================================="
