#!/bin/bash
# ==========================================================
# سكربت تثبيت بوت واتساب شاليهات الثرى — Hetzner
# لا تحتاج تعدل شيئًا — المفتاح السري ينشأ تلقائيًا
# ==========================================================
set -e

EVO_KEY=$(openssl rand -hex 24)

apt-get update -y
apt-get install -y docker.io docker-compose-v2 openssl || apt-get install -y docker.io docker-compose openssl
systemctl enable --now docker

# فتح المنافذ على جدار حماية السيرفر
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 5678 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8080 -j ACCEPT
netfilter-persistent save 2>/dev/null || true

mkdir -p /opt/wabot && cd /opt/wabot

cat > .env <<EOF
EVOLUTION_API_KEY=${EVO_KEY}
EOF

cat > docker-compose.yml <<'COMPOSE'
services:
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: evolution
      POSTGRES_PASSWORD: evo_pass_123
      POSTGRES_DB: evolution
    volumes:
      - pgdata:/var/lib/postgresql/data

  evolution:
    image: atendai/evolution-api:v2.2.3
    restart: always
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    environment:
      SERVER_TYPE: http
      SERVER_PORT: 8080
      AUTHENTICATION_API_KEY: ${EVOLUTION_API_KEY}
      AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES: "true"
      DATABASE_ENABLED: "true"
      DATABASE_PROVIDER: postgresql
      DATABASE_CONNECTION_URI: postgresql://evolution:evo_pass_123@postgres:5432/evolution
      DATABASE_CONNECTION_CLIENT_NAME: evolution
      CACHE_REDIS_ENABLED: "false"
      WEBHOOK_GLOBAL_ENABLED: "true"
      WEBHOOK_GLOBAL_URL: http://n8n:5678/webhook/whatsapp
      WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS: "false"
      WEBHOOK_EVENTS_MESSAGES_UPSERT: "true"
      WEBHOOK_EVENTS_MESSAGES_UPDATE: "false"
      WEBHOOK_EVENTS_CONNECTION_UPDATE: "false"
      QRCODE_LIMIT: "30"
      LOG_LEVEL: ERROR

  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      N8N_SECURE_COOKIE: "false"
      N8N_RUNNERS_ENABLED: "true"
      EVOLUTION_API_KEY: ${EVOLUTION_API_KEY}
      TZ: Asia/Riyadh
      GENERIC_TIMEZONE: Asia/Riyadh
    volumes:
      - n8ndata:/home/node/.n8n

volumes:
  pgdata:
  n8ndata:
COMPOSE

docker compose up -d
echo "DONE" > /opt/wabot/status.txt

echo ""
echo "=============================================="
echo "  التثبيت انتهى"
echo "  مفتاح البوت (احفظه — نحتاجه لاحقًا):"
echo "  ${EVO_KEY}"
echo "=============================================="
