#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

APP_DIR="/opt/conect-stack"
PROJECT_NAME="conect-stack"

clear || true

banner() {
  echo -e "\e[95m==================================================\e[0m"
  echo -e "\e[91m███████╗███╗   ██╗███████╗ ██████╗     ██████╗ ███████╗██╗   ██╗\e[0m"
  echo -e "\e[93m██╔════╝████╗  ██║╚══███╔╝██╔═══██╗    ██╔══██╗██╔════╝██║   ██║\e[0m"
  echo -e "\e[92m█████╗  ██╔██╗ ██║  ███╔╝ ██║   ██║    ██║  ██║█████╗  ██║   ██║\e[0m"
  echo -e "\e[96m██╔══╝  ██║╚██╗██║ ███╔╝  ██║   ██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝\e[0m"
  echo -e "\e[94m███████╗██║ ╚████║███████╗╚██████╔╝    ██████╔╝███████╗ ╚████╔╝\e[0m"
  echo -e "\e[95m╚══════╝╚═╝  ╚═══╝╚══════╝ ╚═════╝     ╚═════╝ ╚══════╝  ╚═══╝\e[0m"
  echo -e "\e[95m==================================================\e[0m"
  echo -e "\e[92m🔥 CONECT STACK INSTALLER — ENZO DEV 🔥\e[0m"
  echo -e "\e[95m==================================================\e[0m"
  echo ""
}

typewriter() {
  local text="$1"
  local delay="${2:-0.012}"

  # interpreta ANSI corretamente
  text=$(printf "%b" "$text")

  for ((i=0; i<${#text}; i++)); do
    printf "%b" "${text:$i:1}"
    sleep "$delay"
  done
  echo ""
}

beep_success() {
  for i in {1..3}; do
    printf '\a'
    sleep 0.15
  done
}

matrix_loader() {
  local msg="$1"
  local pid="$2"

  local cols rows chars colors
  cols=$(tput cols 2>/dev/null || echo 80)
  rows=$(tput lines 2>/dev/null || echo 24)
  chars="01ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%&@{}[]<>/\\|=+-_*"
  colors=(31 32 33 34 35 36 91 92 93 94 95 96)

  clear || true
  tput civis 2>/dev/null || true

  while kill -0 "$pid" >/dev/null 2>&1; do
    for drop in $(seq 1 35); do
      col=$((RANDOM % cols))
      color=${colors[$RANDOM % ${#colors[@]}]}

      for row in $(seq 0 $((rows - 1))); do
        char="${chars:RANDOM%${#chars}:1}"

        tput cup "$row" "$col" 2>/dev/null || true
        echo -ne "\e[${color}m${char}\e[0m"

        if [ "$row" -gt 0 ]; then
          tput cup "$((row - 1))" "$col" 2>/dev/null || true
          echo -ne "\e[2m${char}\e[0m"
        fi
      done
    done

    tput cup 0 0 2>/dev/null || true
    echo -ne "\e[95m🔥 ENZO DEV — ${msg} 🔥\e[0m"
    tput cup 1 0 2>/dev/null || true
    echo -ne "\e[96m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

    sleep 0.08
  done

  tput cnorm 2>/dev/null || true
  clear || true

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
  echo -e "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e "\e[92m🚀 $1\e[0m"
  echo -e "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

ok() {
  echo -e "\e[92m✅ $1\e[0m"
}

warn() {
  echo -e "\e[93m⚠️  $1\e[0m"
}

banner

step "Preparando servidor"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo -e "\e[92m📥 Atualizando workflows do GitHub...\e[0m"

rm -rf /tmp/conect-stack-repo

git clone --depth 1 https://github.com/ceoconectcompany/conect-stack.git /tmp/conect-stack-repo

rm -rf "$APP_DIR/templates"
cp -r /tmp/conect-stack-repo/templates "$APP_DIR/"

rm -rf /tmp/conect-stack-repo

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
  bash -c 'for pkg in ca-certificates curl gnupg lsb-release nano openssl git jq; do
    dpkg -s "$pkg" >/dev/null 2>&1 || apt install -y "$pkg"
  done'
  
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

run_with_matrix "SUBINDO CONECT STACK" "/tmp/conect-stack-up.log" \
  docker compose -p "$PROJECT_NAME" up -d

clear || true
banner

ok "Containers iniciados"

N8N_CONTAINER="$(docker ps --filter "name=${PROJECT_NAME}-n8n" --format '{{.Names}}' | head -n 1)"

echo -e "\e[95m⏳ Aguardando n8n finalizar migrations e liberar banco...\e[0m"

for i in {1..60}; do

  if docker logs "$N8N_CONTAINER" 2>&1 | grep -qi "There was an error running database migrations"; then
    warn "Migration travada detectada. Reiniciando n8n..."
    docker restart "$N8N_CONTAINER" >/dev/null 2>&1 || true
    sleep 20
  fi

  if curl -fsS http://127.0.0.1:5678/healthz >/dev/null 2>&1; then
    ok "n8n pronto"
    break
  fi

  echo -e "\e[95m⏳ Aguardando n8n... tentativa $i/60\e[0m"
  sleep 5
done

sleep 10

step "Importando workflows base"
WORKFLOW_PATH="./templates/base/workflows"

if [ -z "$N8N_CONTAINER" ]; then
  warn "Container do n8n não encontrado. Pulando importação."
elif [ ! -d "$WORKFLOW_PATH" ]; then
  warn "Pasta de workflows não encontrada em $WORKFLOW_PATH. Pulando importação."
else
  echo -e "\e[92m📂 Pasta encontrada: \e[95m$WORKFLOW_PATH\e[0m"
  echo -e "\e[92m🐳 Container n8n: \e[95m$N8N_CONTAINER\e[0m"

  echo -e "\e[92m🧪 Validando JSON dos workflows...\e[0m"
  find "$WORKFLOW_PATH" -name "*.json" -type f -print -exec jq empty {} \;

  echo -e "\e[92m📥 Copiando workflows para o container...\e[0m"
  docker cp "$WORKFLOW_PATH" "$N8N_CONTAINER:/tmp/workflows"

  echo -e "\e[92m⚙️ Importando workflows no n8n...\e[0m"
  docker exec "$N8N_CONTAINER" n8n import:workflow --separate --input=/tmp/workflows

  ok "Workflows base importados"
fi

step "Aguardando serviços ficarem online"

sleep 3

for i in {1..15}; do
  if curl -fsS http://localhost:5678 >/dev/null 2>&1; then
    ok "n8n online"
    break
  fi

  if [ "$i" -eq 15 ]; then
    warn "n8n ainda não respondeu, mas o container pode estar iniciando"
  fi

  sleep 3
done

for i in {1..15}; do
  if curl -fsS http://localhost:3000 >/dev/null 2>&1; then
    ok "WAHA online"
    break
  fi

  if [ "$i" -eq 15 ]; then
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

beep_success

clear || true
banner

typewriter "\e[95m🔥 CONECT STACK INSTALADA COM SUCESSO 🔥\e[0m" 0.01
sleep 0.2
echo ""

typewriter "\e[92m🌐 n8n:\e[0m" 0.01
typewriter "\e[95mhttp://${IPV4}:5678\e[0m" 0.008
sleep 0.2
echo ""

typewriter "\e[92m🌐 WAHA:\e[0m" 0.01
typewriter "\e[95mhttp://${IPV4}:3000\e[0m" 0.008
sleep 0.2
echo ""

typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m🔐 ACESSO N8N\e[0m" 0.01
typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m👤 Login:    \e[95m${N8N_USER}\e[0m" 0.008
typewriter "\e[92m🔑 Password: \e[95m${N8N_PASSWORD}\e[0m" 0.008
echo ""

typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m🔐 ACESSO WAHA DASHBOARD\e[0m" 0.01
typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m👤 Login:    \e[95m${WAHA_USER}\e[0m" 0.008
typewriter "\e[92m🔑 Password: \e[95m${WAHA_PASSWORD}\e[0m" 0.008
echo ""

typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m🔑 WAHA API KEY\e[0m" 0.01
typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[95m${WAHA_API_KEY}\e[0m" 0.004
echo ""

typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002
typewriter "\e[92m🐳 CONTAINERS\e[0m" 0.01
typewriter "\e[95m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" 0.002

echo -e "\e[95m"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo -e "\e[0m"

echo ""
typewriter "\e[92m✅ Finalizado por ENZO DEV\e[0m" 0.01
typewriter "\e[95m==================================================\e[0m" 0.002
beep_success

# ==============================
# 🔥 ENZO DEV PANEL AUTOMÁTICO
# ==============================

cat > /root/painel.sh << 'EOF'
#!/bin/bash

IP=$(curl -4 -s https://api.ipify.org || hostname -I | awk '{print $1}')

N8N_CONTAINER=$(docker ps --filter "name=n8n" --format '{{.Names}}' | head -n 1)
WAHA_CONTAINER=$(docker ps --filter "name=waha" --format '{{.Names}}' | head -n 1)

N8N_USER=$(docker exec "$N8N_CONTAINER" printenv N8N_BASIC_AUTH_USER 2>/dev/null)
N8N_PASS=$(docker exec "$N8N_CONTAINER" printenv N8N_BASIC_AUTH_PASSWORD 2>/dev/null)

WAHA_KEY=$(docker inspect "$WAHA_CONTAINER" 2>/dev/null | grep WAHA_API_KEY | head -1 | cut -d '"' -f4)

clear

echo "========================================"
echo "🔥 ENZO DEV PANEL 🔥"
echo "========================================"
echo ""
echo "🌐 n8n:"
echo "http://$IP:5678"
echo ""
echo "🌐 WAHA:"
echo "http://$IP:3000"
echo ""
echo "========================================"
echo "🔐 N8N LOGIN"
echo "========================================"
echo "User: ${N8N_USER:-admin}"
echo "Pass: ${N8N_PASS:-(ver no container)}"
echo ""
echo "========================================"
echo "🔐 WAHA API KEY"
echo "========================================"
echo "${WAHA_KEY:-(não encontrada)}"
echo ""
echo "========================================"
EOF

chmod +x /root/painel.sh

# adicionar no bashrc se ainda não existir
grep -qxF "/root/painel.sh" /root/.bashrc || echo "/root/painel.sh" >> /root/.bashrc

echo "🔥 ENZO DEV PANEL INSTALADO COM SUCESSO 🔥"
