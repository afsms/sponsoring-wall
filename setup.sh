#!/bin/bash
set -e

# ============================================================
# SPONSORING WALL - PRODUKTIONS SETUP SCRIPT
# Führe dieses Script einmalig nach git clone aus
# ============================================================

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        SPONSORING WALL - PRODUKTIONS SETUP           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ------------------------------------------------------------
# Voraussetzungen prüfen
# ------------------------------------------------------------
echo "▶ Prüfe Voraussetzungen..."

command -v docker >/dev/null 2>&1 || { echo "❌ Docker nicht gefunden. Bitte installieren."; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo "❌ Docker Compose nicht gefunden. Bitte installieren."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "❌ OpenSSL nicht gefunden. Bitte installieren."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js nicht gefunden. Bitte installieren."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 nicht gefunden. Bitte installieren."; exit 1; }

# pycryptodome installieren falls nötig
if ! python3 -c "from Crypto.Cipher import AES" 2>/dev/null && \
   ! python3 -c "from Cryptodome.Cipher import AES" 2>/dev/null; then
    echo "  ℹ️  Installiere pycryptodome..."
    sudo apt-get install -y python3-pycryptodome 2>/dev/null || \
    sudo apt-get install -y python3-pip 2>/dev/null && \
    pip3 install pycryptodome --break-system-packages 2>/dev/null || true
fi

echo "✅ Alle Voraussetzungen erfüllt."
echo ""

# ------------------------------------------------------------
# Konfiguration abfragen
# ------------------------------------------------------------
echo "▶ Konfiguration:"
read -p "  Deine Domain oder IP (z.B. sponsoring.example.com oder 192.168.1.100): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain darf nicht leer sein."
    exit 1
fi

read -p "  Admin-Passwort für das Admin-Dashboard: " ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Admin-Passwort darf nicht leer sein."
    exit 1
fi

echo ""

# ------------------------------------------------------------
# Secrets generieren
# ------------------------------------------------------------
echo "▶ Generiere sichere Secrets..."

POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9_' | head -c 32)
JWT_SECRET=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
DB_ENC_KEY=$(openssl rand -hex 8)  # exakt 16 Zeichen

echo "  ✅ PostgreSQL Passwort generiert"
echo "  ✅ JWT Secret generiert"
echo "  ✅ Secret Key Base generiert"
echo "  ✅ Encryption Key generiert"
echo ""

# ------------------------------------------------------------
# JWT Keys generieren
# ------------------------------------------------------------
echo "▶ Generiere JWT Keys..."

cat > /tmp/gen_jwt.js << EOF
const crypto = require('crypto');
const secret = '${JWT_SECRET}';
const now = Math.floor(Date.now() / 1000);
const exp = now + (10 * 365 * 24 * 60 * 60);

function base64url(str) {
    return Buffer.from(str).toString('base64')
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function sign(payload) {
    const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
    const body = base64url(JSON.stringify(payload));
    const sig = crypto.createHmac('sha256', secret)
        .update(header + '.' + body).digest('base64')
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    return header + '.' + body + '.' + sig;
}

const anon = sign({ role: 'anon', iss: 'supabase', iat: now, exp });
const service = sign({ role: 'service_role', iss: 'supabase', iat: now, exp });

console.log('ANON=' + anon);
console.log('SERVICE=' + service);
EOF

JWT_OUTPUT=$(node /tmp/gen_jwt.js)
ANON_KEY=$(echo "$JWT_OUTPUT" | grep '^ANON=' | cut -d'=' -f2-)
SERVICE_KEY=$(echo "$JWT_OUTPUT" | grep '^SERVICE=' | cut -d'=' -f2-)
rm /tmp/gen_jwt.js

echo "  ✅ Anon Key generiert"
echo "  ✅ Service Role Key generiert"
echo ""

# ------------------------------------------------------------
# AES-ECB Verschlüsselung für Realtime DB
# ------------------------------------------------------------
echo "▶ Verschlüssele Secrets für Realtime..."

python3 -c "
import sys, base64

try:
    from Crypto.Cipher import AES
except ImportError:
    from Cryptodome.Cipher import AES

key = b'${DB_ENC_KEY}'

def encrypt(text):
    data = text.encode()
    to_add = 16 - (len(data) % 16)
    padded = data + bytes([to_add] * to_add)
    return base64.b64encode(AES.new(key, AES.MODE_ECB).encrypt(padded)).decode()

print('ENC_JWT=' + encrypt('${JWT_SECRET}'))
print('ENC_DB_HOST=' + encrypt('db'))
print('ENC_DB_PORT=' + encrypt('5432'))
print('ENC_DB_NAME=' + encrypt('postgres'))
print('ENC_DB_USER=' + encrypt('postgres'))
print('ENC_DB_PASS=' + encrypt('${POSTGRES_PASSWORD}'))
print('ENC_SSL=' + encrypt('false'))
" > /tmp/enc_output.txt

ENC_JWT=$(grep '^ENC_JWT=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_DB_HOST=$(grep '^ENC_DB_HOST=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_DB_PORT=$(grep '^ENC_DB_PORT=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_DB_NAME=$(grep '^ENC_DB_NAME=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_DB_USER=$(grep '^ENC_DB_USER=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_DB_PASS=$(grep '^ENC_DB_PASS=' /tmp/enc_output.txt | cut -d'=' -f2-)
ENC_SSL=$(grep '^ENC_SSL=' /tmp/enc_output.txt | cut -d'=' -f2-)
rm /tmp/enc_output.txt

echo "  ✅ Alle Werte verschlüsselt"
echo ""

# ------------------------------------------------------------
# .env Datei erstellen
# ------------------------------------------------------------
echo "▶ Erstelle .env Datei..."

cat > .env << EOF
# ============================================================
# GENERIERT VON setup.sh - NICHT MANUELL BEARBEITEN
# ============================================================

# --- DATENBANK ---
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres
POSTGRES_USER=postgres

# --- AUTH & JWT ---
JWT_SECRET=${JWT_SECRET}
ANON_KEY=${ANON_KEY}
SERVICE_KEY=${SERVICE_KEY}

# --- REALTIME ---
REALTIME_ENCRYPTION_KEY=${DB_ENC_KEY}
SECRET_KEY_BASE=${SECRET_KEY_BASE}

# --- FRONTEND ---
VITE_SUPABASE_URL=http://${DOMAIN}:8000
VITE_SUPABASE_ANON_KEY=${ANON_KEY}
VITE_ADMIN_PASSWORD=${ADMIN_PASSWORD}

# --- ADMIN ---
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# --- DOMAIN ---
DOMAIN=${DOMAIN}
EOF

chmod 600 .env
echo "  ✅ .env Datei erstellt (chmod 600)"
echo ""

# ------------------------------------------------------------
# init-realtime.sh generieren
# ------------------------------------------------------------
echo "▶ Generiere init-realtime.sh..."

cat > scripts/init-realtime.sh << EOF
#!/bin/sh
set -e
export PGPASSWORD=\${POSTGRES_PASSWORD}

echo "Warte auf Datenbank..."
sleep 3

psql -h db -U postgres -d postgres <<-EOSQL
  INSERT INTO public.tenants (id, name, external_id, jwt_secret, inserted_at, updated_at)
  VALUES (
    gen_random_uuid(),
    'realtime',
    'realtime',
    '${ENC_JWT}',
    now(),
    now()
  )
  ON CONFLICT (external_id) DO UPDATE SET
    jwt_secret = EXCLUDED.jwt_secret,
    updated_at = now();

  INSERT INTO public.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at)
  VALUES (
    gen_random_uuid(),
    'postgres_cdc_rls',
    '{
      "db_host": "${ENC_DB_HOST}",
      "db_port": "${ENC_DB_PORT}",
      "db_name": "${ENC_DB_NAME}",
      "db_user": "${ENC_DB_USER}",
      "db_password": "${ENC_DB_PASS}",
      "db_ssl": false,
      "ssl_enforced": false,
      "region": "eu-west-1",
      "publication": "supabase_realtime",
      "slot_name": "supabase_realtime_replication_slot",
      "poll_interval_ms": 100,
      "poll_max_changes": 100,
      "poll_max_record_bytes": 1048576
    }',
    'realtime',
    now(),
    now()
  )
  ON CONFLICT DO NOTHING;
EOSQL

echo "✅ Realtime Tenant konfiguriert."
EOF

chmod +x scripts/init-realtime.sh
echo "  ✅ init-realtime.sh generiert"
echo ""

# ------------------------------------------------------------
# docker-compose.prod.yml generieren
# ------------------------------------------------------------
echo "▶ Generiere docker-compose.prod.yml..."

cat > docker-compose.prod.yml << EOF
services:
  db:
    container_name: sponsoring-wall-db
    image: supabase/postgres:15.1.1.78
    restart: always
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
    volumes:
      - db_data:/var/lib/postgresql/data
    command: postgres -c listen_addresses='*' -c wal_level=logical
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10

  realtime-setup:
    image: postgres:15-alpine
    restart: "no"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./scripts/init-realtime.sh:/init-realtime.sh
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    entrypoint: ["/bin/sh", "/init-realtime.sh"]

  rest:
    image: postgrest/postgrest:v12.2.0
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://postgres:\${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public,api
      PGRST_DB_ANON_ROLE: anon
      PGRST_DB_EXTRA_SEARCH_PATH: public,api
      PGRST_JWT_SECRET: \${JWT_SECRET}

  realtime:
    image: ghcr.io/supabase/realtime:v2.78.11
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      PORT: "4000"
      HOSTNAME: localhost
      APP_NAME: realtime
      DB_HOST: db
      DB_NAME: postgres
      DB_USER: postgres
      DB_PASSWORD: \${POSTGRES_PASSWORD}
      DB_PORT: "5432"
      DB_SSL: "false"
      REPLICATION_MODE: PUBLICATION
      JWT_SECRET: \${JWT_SECRET}
      API_JWT_SECRET: \${JWT_SECRET}
      METRICS_JWT_SECRET: \${JWT_SECRET}
      SECRET_KEY_BASE: \${SECRET_KEY_BASE}
      DB_ENC_KEY: \${REALTIME_ENCRYPTION_KEY}
      SECURE_CHANNELS: "false"

  kong:
    container_name: sponsoring-wall-kong
    image: kong:2.8.1-alpine
    restart: always
    ports:
      - "8000:8000"
    depends_on:
      - rest
      - realtime
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yml
    volumes:
      - ./supabase/kong.yml:/etc/kong/kong.yml

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        - VITE_SUPABASE_URL=https://\${DOMAIN}
        - VITE_SUPABASE_ANON_KEY=\${ANON_KEY}
        - VITE_ADMIN_PASSWORD=\${ADMIN_PASSWORD}
    ports:
      - "80:80"
    restart: always
    depends_on:
      - kong

volumes:
  db_data:
EOF

echo "  ✅ docker-compose.prod.yml generiert"
echo ""

# ------------------------------------------------------------
# DB Initialisierung vorbereiten
# ------------------------------------------------------------
echo "▶ Prüfe init-db.sql..."
if [ ! -f "supabase/init-db.sql" ]; then
    echo "  ⚠️  supabase/init-db.sql nicht gefunden!"
    echo "  Bitte stelle sicher dass die Datei vorhanden ist."
else
    echo "  ✅ init-db.sql gefunden"
fi
echo ""

# ------------------------------------------------------------
# .gitignore sicherstellen
# ------------------------------------------------------------
echo "▶ Aktualisiere .gitignore..."
for f in ".env" ".env.prod" "docker-compose.prod.yml" "scripts/init-realtime.sh"; do
    grep -qxF "$f" .gitignore 2>/dev/null || echo "$f" >> .gitignore
done
echo "  ✅ .gitignore aktualisiert"
echo ""

# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------
echo "╔══════════════════════════════════════════════════════╗"
echo "║                    SETUP ABGESCHLOSSEN               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Frontend:    http://${DOMAIN}"
echo "  API:         http://${DOMAIN}:8000"
echo "  Admin PW:    ${ADMIN_PASSWORD}"
echo ""
echo "  Generierte Dateien:"
echo "    ✅ .env"
echo "    ✅ scripts/init-realtime.sh"
echo "    ✅ docker-compose.prod.yml"
echo ""
echo "  Nächste Schritte:"
echo ""
echo "  1. Starte die App:"
echo ""
echo "     docker compose -f docker-compose.prod.yml up -d --build"
echo ""
echo "  2. Initialisiere die Datenbank (einmalig):"
echo ""
echo "     docker exec -i sponsoring-wall-db psql -U postgres -d postgres < supabase/init-db.sql"
echo "     docker exec -i sponsoring-wall-db psql -U supabase_admin -d postgres -c \"GRANT ALL ON SCHEMA realtime TO postgres; ALTER SCHEMA realtime OWNER TO postgres; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO postgres; GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA realtime TO postgres;\""
echo "     docker exec -i sponsoring-wall-db psql -U supabase_admin -d postgres -c \"ALTER USER postgres WITH SUPERUSER;\""
echo ""
echo "  3. Nginx Proxy Manager konfigurieren:"
echo "     - Frontend: http://sponsoring-wall-frontend-1:80"
echo "     - API:      http://sponsoring-wall-kong:8000"
echo ""
echo "  ⚠️  WICHTIG: .env und die generierten Dateien NIEMALS ins Git committen!"
echo ""