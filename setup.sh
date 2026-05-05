#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "🚀 CONECT STACK SETUP PRO"

# ==============================
# 🔓 BLINDAGEM APT (SEM ERRO)
# ==============================
echo "🛑 Parando APT automático..."
systemctl stop apt-daily.timer || true
systemctl stop apt-daily-upgrade.timer || true
systemctl disable apt-daily.timer || true
systemctl disable apt-daily-upgrade.timer || true

systemctl stop apt-daily.service || true
systemctl stop apt-daily-upgrade.service || true
systemctl stop unattended-upgrades || true

echo "⏳ Aguardando locks..."
for i in {1..30}; do
  if ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
     ! fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

dpkg --configure -a || true

apt update -y
apt install -y ca-certificates curl gnupg lsb-release git openssl jq python3

# ==============================
# 🐳 DOCKER
# ==============================
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker
systemctl start docker

# ==============================
# 📦 REPO
# ==============================
ROOT_DIR="/opt/conect-stack"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"

rm -rf "$ROOT_DIR"
git clone "$REPO_URL" "$ROOT_DIR"

cd "$ROOT_DIR"

# ==============================
# 🔐 CONFIG CLIENTE (INTERATIVO)
# ==============================
echo ""
echo "🔧 CONFIGURAÇÃO DO CLIENTE"
read -p "Nome do cliente: " CLIENT_NAME
read -p "WAHA API KEY: " WAHA_KEY
read -p "Telegram BOT TOKEN: " TELEGRAM_TOKEN
read -p "Telegram CHAT ID: " TELEGRAM_CHAT

# ==============================
# 🧠 INJETAR CONFIG NOS JSON
# ==============================
echo "⚙️ Aplicando config nos workflows..."

for f in templates/base/workflows/*.json; do
  echo "👉 Ajustando $f"

  jq \
    --arg name "$CLIENT_NAME" \
    --arg key "$WAHA_KEY" \
    --arg ttoken "$TELEGRAM_TOKEN" \
    --arg tchat "$TELEGRAM_CHAT" \
    '
    (.nodes[]?.parameters?.jsCode) |=
    if . then
      gsub("NOME_DO_CLIENTE"; $name) |
      gsub("SUA_WAHA_API_KEY"; $key) |
      gsub("SEU_BOT_TOKEN_TELEGRAM"; $ttoken) |
      gsub("SEU_CHAT_ID_TELEGRAM"; $tchat)
    else . end
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"

done

# ==============================
# 🧪 VALIDAR JSON
# ==============================
echo "🧪 Validando workflows..."

for f in templates/base/workflows/*.json; do
  echo "Validando: $f"
  if ! python3 -m json.tool "$f" >/dev/null; then
    echo "❌ JSON inválido em $f"
    exit 1
  fi
done

echo "✅ JSON OK"

# ==============================
# 🐳 DOCKER COMPOSE
# ==============================
WAHA_API_KEY="$WAHA_KEY"

cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=0.0.0.0
      - TZ=America/Sao_Paulo
    volumes:
      - n8n_data:/home/node/.n8n

  waha:
    image: devlikeapro/waha:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - WAHA_API_KEY=$WAHA_API_KEY

volumes:
  n8n_data:
EOF

docker compose up -d

# ==============================
# ⏳ AGUARDAR N8N
# ==============================
echo "⏳ Aguardando n8n..."

for i in {1..30}; do
  if curl -s http://localhost:5678 >/dev/null; then
    echo "✅ n8n online"
    break
  fi
  sleep 2
done

# ==============================
# 📥 IMPORTAR WORKFLOWS (SAFE)
# ==============================
echo "📥 Importando workflows..."

docker cp templates/base/workflows/. conect-stack-n8n-1:/tmp/import/

docker exec conect-stack-n8n-1 sh -c '
for f in /tmp/import/*.json; do
  echo "Importando: $f"
  n8n import:workflow --input="$f" || echo "⚠️ Erro ignorado em $f"
done
'

# ==============================
# 🌐 FINAL
# ==============================
IP=$(curl -s ifconfig.me)

echo ""
echo "========================================"
echo "🔥 STACK PRONTA 🔥"
echo "========================================"
echo "🌐 n8n: http://$IP:5678"
echo "🌐 WAHA: http://$IP:3000"
echo "========================================"
