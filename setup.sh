#!/bin/bash
set -euo pipefail

clear || true

echo "========================================"
echo "🚀 CONECT STACK - SETUP MASTER"
echo "========================================"

export DEBIAN_FRONTEND=noninteractive

ROOT_DIR="/opt/conect-kit"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"

echo "📦 Atualizando VPS..."
apt update -y
apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo "📦 Instalando dependências..."
apt install -y ca-certificates curl gnupg lsb-release nano openssl git jq

if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
else
  echo "✅ Docker já instalado."
fi

apt install -y docker-compose-plugin

echo "📁 Preparando pasta..."
rm -rf "$ROOT_DIR"
git clone "$REPO_URL" "$ROOT_DIR"

cd "$ROOT_DIR/conect-installer-modular-pronto"

if [ ! -f "install.sh" ]; then
  echo "❌ install.sh não encontrado em conect-installer-modular-pronto"
  exit 1
fi

chmod +x install.sh

echo ""
echo "✅ Setup base concluído."
echo "➡️ Agora rodando installer modular..."
echo ""

bash install.sh
