#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "🚀 CONECT STACK SETUP INICIANDO..."

apt update -y
apt install -y git curl

if [ ! -d "/opt/conect-stack/.git" ]; then
  echo "📥 Clonando repositório..."
  rm -rf /opt/conect-stack
  git clone https://github.com/ceoconectcompany/conect-stack.git /opt/conect-stack
else
  echo "🔄 Atualizando repositório..."
  git -C /opt/conect-stack pull origin main
fi

cd /opt/conect-stack

echo "🔥 Abrindo CONECT INSTALLER..."
bash install.sh
