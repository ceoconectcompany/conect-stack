#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "🚀 CONECT STACK SETUP MASTER"

apt update -y
apt install -y ca-certificates curl gnupg git docker.io docker-compose-plugin

systemctl enable docker
systemctl start docker

ROOT_DIR="/opt/conect-stack"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"

if [ ! -d "$ROOT_DIR/.git" ]; then
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  git -C "$ROOT_DIR" pull origin main
fi

cd "$ROOT_DIR"

if [ ! -f "docker-compose.yml" ] && [ ! -f "compose.yml" ]; then
  cat > docker-compose.yml <<'EOF'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - TZ=America/Sao_Paulo
    volumes:
      - n8n_data:/home/node/.n8n

  waha:
    image: devlikeapro/waha:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - WAHA_API_KEY=123456

volumes:
  n8n_data:
EOF
fi

docker compose up -d

echo "⏳ Aguardando n8n subir..."
sleep 20

bash install.sh