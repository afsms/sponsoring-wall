-- 1. ROLLEN
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END $$;

GRANT anon TO postgres;

-- 2. SCHEMA & TABELLEN
CREATE SCHEMA IF NOT EXISTS public;
ALTER SCHEMA public OWNER TO postgres;

-- Tabellen anlegen
CREATE TABLE IF NOT EXISTS public.sponsors (
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

CREATE TABLE IF NOT EXISTS public.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC DEFAULT 2480,
    price_per_unit NUMERIC DEFAULT 15.15,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM public.project_settings);

-- 3. RECHTE (Der Fix!)
-- Wir geben anon explizit USAGE auf das Schema und SELECT auf alle Tabellen
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;

-- Suchpfad für anon festlegen
ALTER ROLE anon SET search_path TO public, extensions;

-- 4. REALTIME
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime FOR TABLE public.sponsors;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- PostgREST benachrichtigen
NOTIFY pgrst, 'reload schema';
