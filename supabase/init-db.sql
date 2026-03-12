-- 1. ROLLEN & BASIS
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END $$;

GRANT anon TO postgres;

-- 2. DAS NEUE API SCHEMA
CREATE SCHEMA IF NOT EXISTS api;
ALTER SCHEMA api OWNER TO postgres;
GRANT USAGE ON SCHEMA api TO anon;

-- 3. TABELLEN (Frisch im api schema)
DROP TABLE IF EXISTS api.sponsors CASCADE;
CREATE TABLE api.sponsors (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    iban TEXT,
    sq_meters INTEGER NOT NULL DEFAULT 1,
    mandate_accepted BOOLEAN DEFAULT FALSE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    total_amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

DROP TABLE IF EXISTS api.project_settings CASCADE;
CREATE TABLE api.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC DEFAULT 2480,
    price_per_unit NUMERIC DEFAULT 15.15,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO api.project_settings (goal_sq_meters, price_per_unit) VALUES (2480, 15.15);

-- 4. BERECHTIGUNGEN
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA api TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO anon;

-- Suchpfad festlegen
ALTER ROLE anon SET search_path TO api, public, extensions;
ALTER ROLE postgres SET search_path TO api, public, extensions;

-- 5. REALTIME (Sponsoren-Tabelle anmelden)
DO $$
BEGIN
    DROP PUBLICATION IF EXISTS supabase_realtime;
    CREATE PUBLICATION supabase_realtime FOR TABLE api.sponsors;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Cache-Update erzwingen
NOTIFY pgrst, 'reload schema';
