#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "🚀 CONECT STACK SIMPLES"

ROOT_DIR="/opt/conect-stack"
REPO_URL="https://github.com/ceoconectcompany/conect-stack.git"
N8N_CONTAINER="conect-stack-n8n-1"
WAHA_API_KEY="$(openssl rand -hex 32)"

echo "🛑 Liberando APT..."
systemctl stop apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service unattended-upgrades 2>/dev/null || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
dpkg --configure -a || true

apt update -y
apt install -y ca-certificates curl gnupg git openssl python3 jq

if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker
systemctl start docker

echo "📥 Baixando repo..."
rm -rf "$ROOT_DIR"
git clone "$REPO_URL" "$ROOT_DIR"
cd "$ROOT_DIR"

cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: conect-stack-n8n-1
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
    container_name: conect-stack-waha-1
    restart: always
    ports:
      - "3000:3000"
    environment:
      - WAHA_API_KEY=$WAHA_API_KEY

volumes:
  n8n_data:
EOF

echo "🐳 Subindo n8n + WAHA..."
docker compose up -d

echo "⏳ Aguardando n8n..."
for i in {1..60}; do
  if curl -s http://localhost:5678 >/dev/null; then
    echo "✅ n8n online"
    break
  fi
  sleep 2
done

WF_DIR="$ROOT_DIR/templates/base/workflows"

echo "🧪 Validando workflows..."
for f in "$WF_DIR"/*.json; do
  echo "Validando: $(basename "$f")"
  python3 -m json.tool "$f" >/dev/null
done

echo "📥 Importando 3 workflows base..."
docker exec "$N8N_CONTAINER" sh -c "rm -rf /tmp/import && mkdir -p /tmp/import"
docker cp "$WF_DIR/." "$N8N_CONTAINER:/tmp/import/"

for f in "$WF_DIR"/*.json; do
  base="$(basename "$f")"
  echo "📥 Importando: $base"
  docker exec -u node "$N8N_CONTAINER" n8n import:workflow --input="/tmp/import/$base"
done

IP="$(curl -s ifconfig.me || hostname -I | awk '{print $1}')"

echo ""
echo "========================================"
echo "🔥 CONECT STACK INSTALADA 🔥"
echo "========================================"
echo "🌐 n8n:  http://$IP:5678"
echo "🌐 WAHA: http://$IP:3000"
echo ""
echo "🔐 WAHA API KEY:"
echo "$WAHA_API_KEY"
echo ""
echo "📦 Workflows importados:"
echo "- ping-waha"
echo "- monitoramento-waha"
echo "- restart-preventivo"
echo "========================================"
