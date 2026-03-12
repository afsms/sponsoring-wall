-- 1. Alles auf Null für das public Schema
CREATE SCHEMA IF NOT EXISTS public;
ALTER SCHEMA public OWNER TO postgres;

-- 2. Rollen sicherstellen
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

-- 3. Tabellen anlegen
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

-- Seed Daten falls leer
INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 
WHERE NOT EXISTS (SELECT 1 FROM public.project_settings);

-- 4. BERECHTIGUNGEN (Der wichtigste Teil)
-- Dem Benutzer anon explizit Zugriff auf ALLES im public Schema geben
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- Sicherstellen, dass neue Tabellen auch automatisch Rechte bekommen
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;

-- 5. Suchpfad für die Rollen festlegen
ALTER ROLE anon SET search_path TO public;
ALTER ROLE postgres SET search_path TO public;

-- 6. Realtime vorbereiten
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;
-- Versuchen die Tabelle hinzuzufügen (ignoriert Fehler falls schon drin)
BEGIN;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.sponsors;
COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK;
