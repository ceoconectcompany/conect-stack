#!/bin/bash
set -e

echo "🔥 CONECT STACK OK"
echo "Rodando script direto da raiz com sucesso"
echo "IP:"
curl -4 -s ifconfig.me || hostname -I
echo ""
