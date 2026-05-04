#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "🚀 CONECT STACK SETUP MASTER"

apt update -y
apt install -y ca-certificates curl gnupg lsb-release git openssl

# Instalar Docker oficial
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
else
  echo "✅ Docker já instalado."
fi

systemctl enable docker
systemctl start docker

# Instalar Docker Compose Plugin
if ! docker compose version >/dev/null 2>&1; then
  echo "📦 Instalando Docker Compose Plugin..."

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update -y
  apt install -y docker-compose-plugin
else
  echo "✅ Docker Compose já instalado."
fi

# Gerar API KEY automática
WAHA_API_KEY=$(openssl rand -hex 32)

ROOT_DIR="/opt/conect-stack"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"

if [ ! -d "$ROOT_DIR/.git" ]; then
  rm -rf "$ROOT_DIR"
  git clone "$REPO_URL" "$ROOT_DIR"
else
  git -C "$ROOT_DIR" pull origin main
fi

cd "$ROOT_DIR"

# Criar docker-compose se não existir
if [ ! -f "docker-compose.yml" ] && [ ! -f "compose.yml" ]; then
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
      - WAHA_API_KEY=$WAHA_API_KEY

volumes:
  n8n_data:
EOF
fi

docker compose up -d

echo "⏳ Aguardando n8n subir..."

for i in {1..30}; do
  if curl -s http://localhost:5678 >/dev/null; then
    echo "✅ n8n está online!"
    break
  fi
  sleep 2
done

# Rodar install.sh se existir
if [ -f "install.sh" ]; then
  echo "📦 Rodando install.sh..."
  bash install.sh
else
  echo "⚠️ install.sh não encontrado. Pulando etapa extra."
fi

# Mostrar acesso
IP=$(curl -s ifconfig.me)

echo ""
echo "========================================"
echo "🔥 CONECT STACK INSTALADA COM SUCESSO 🔥"
echo "========================================"
echo ""
echo "🌐 n8n: http://$IP:5678"
echo "🌐 WAHA: http://$IP:3000"
echo ""
echo "🔐 WAHA API KEY: $WAHA_API_KEY"
echo ""
echo "📦 Pasta: $ROOT_DIR"
echo ""
