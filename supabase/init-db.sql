-- 1. ROLLEN-SETUP
ALTER USER postgres WITH SUPERUSER;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
END
$$;

GRANT anon TO postgres;

-- 2. API SCHEMA
CREATE SCHEMA IF NOT EXISTS api;
ALTER SCHEMA api OWNER TO postgres;
GRANT USAGE ON SCHEMA api TO anon;

-- 3. TABELLEN (im api schema)
DROP TABLE IF EXISTS api.sponsors CASCADE;
CREATE TABLE api.sponsors (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(255),
    iban VARCHAR(255),
    sq_meters INTEGER NOT NULL DEFAULT 1,
    mandate_accepted BOOLEAN NOT NULL DEFAULT FALSE,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    total_amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS api.project_settings CASCADE;
CREATE TABLE api.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC(10, 2) DEFAULT 2480,
    price_per_unit NUMERIC(10, 2) DEFAULT 15.15,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO api.project_settings (goal_sq_meters, price_per_unit) VALUES (2480, 15.15);

-- 4. BERECHTIGUNGEN
GRANT ALL ON ALL TABLES IN SCHEMA api TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA api TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO anon;

-- Suchpfad für alle festlegen
ALTER ROLE anon SET search_path TO api, public, extensions;
ALTER ROLE postgres SET search_path TO api, public, extensions;

-- 5. REALTIME
DO $$
BEGIN
    DROP PUBLICATION IF EXISTS supabase_realtime;
    CREATE PUBLICATION supabase_realtime FOR TABLE api.sponsors;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- PostgREST Cache Leeren
NOTIFY pgrst, 'reload schema';
