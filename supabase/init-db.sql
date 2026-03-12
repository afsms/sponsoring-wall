-- Grundlegende Berechtigung
ALTER USER postgres WITH SUPERUSER;

-- Rollen sicherstellen
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
END
$$;

-- WICHTIG: Admin darf anon Rolle nutzen
GRANT anon TO postgres;
GRANT authenticated TO postgres;

-- Tabellen im public Schema
CREATE TABLE IF NOT EXISTS public.sponsors (
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

CREATE TABLE IF NOT EXISTS public.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC(10, 2) DEFAULT 2480,
    price_per_unit NUMERIC(10, 2) DEFAULT 15.15,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM public.project_settings);

-- Alles für anon freischalten
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER ROLE anon SET search_path TO public;
