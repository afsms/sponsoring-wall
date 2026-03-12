-- 1. ROLLEN
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END $$;
GRANT anon TO postgres;

-- 2. SCHEMAS
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS public;

-- 3. FUNKTION FÜR TABELLEN-SETUP
CREATE OR REPLACE FUNCTION setup_tables(schema_name text) RETURNS void AS $$
BEGIN
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.sponsors (
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
    )', schema_name);

    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.project_settings (
        id SERIAL PRIMARY KEY,
        goal_sq_meters NUMERIC DEFAULT 2480,
        price_per_unit NUMERIC DEFAULT 15.15,
        updated_at TIMESTAMPTZ DEFAULT NOW()
    )', schema_name);

    EXECUTE format('INSERT INTO %I.project_settings (goal_sq_meters, price_per_unit) 
                    SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM %I.project_settings)', schema_name, schema_name);

    EXECUTE format('GRANT USAGE ON SCHEMA %I TO anon', schema_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO anon', schema_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO anon', schema_name);
END;
$$ LANGUAGE plpgsql;

-- Tabellen in beiden Schemas anlegen (Absolute Sicherheit)
SELECT setup_tables('public');
SELECT setup_tables('api');

-- 4. SUCHPFAD & CACHE
ALTER ROLE anon SET search_path TO api, public, extensions;
ALTER ROLE postgres SET search_path TO api, public, extensions;
ALTER DATABASE postgres SET search_path TO api, public, extensions;

-- Realtime
DO $$ BEGIN
    DROP PUBLICATION IF EXISTS supabase_realtime;
    CREATE PUBLICATION supabase_realtime FOR TABLE public.sponsors, api.sponsors;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';
