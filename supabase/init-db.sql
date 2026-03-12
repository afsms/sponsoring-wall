-- 1. ROLLEN & BASIS-RECHTE
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END $$;

-- WICHTIG: Erlaube der API, in diese Rollen zu schlüpfen
GRANT anon TO postgres;
GRANT authenticated TO postgres;

-- 2. SCHEMA-REINIGUNG
-- Wir stellen sicher, dass das public-Schema wirklich "sauber" ist
CREATE SCHEMA IF NOT EXISTS public;
ALTER SCHEMA public OWNER TO postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA public TO public;

-- 3. TABELLEN (Frisch anlegen)
DROP TABLE IF EXISTS public.sponsors CASCADE;
CREATE TABLE public.sponsors (
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

DROP TABLE IF EXISTS public.project_settings CASCADE;
CREATE TABLE public.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC DEFAULT 2480,
    price_per_unit NUMERIC DEFAULT 15.15,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) VALUES (2480, 15.15);

-- 4. RECHTE-HAMMER
ALTER TABLE public.sponsors OWNER TO postgres;
ALTER TABLE public.project_settings OWNER TO postgres;

-- Jeder darf alles (für den Test)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;

-- Sicherheit abschalten
ALTER TABLE public.sponsors DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_settings DISABLE ROW LEVEL SECURITY;

-- 5. SYSTEM-WEITER SUCHPFAD
-- Das hier zwingt die Datenbank, sponsors IMMER als public.sponsors zu erkennen
ALTER ROLE anon SET search_path TO public, extensions;
ALTER ROLE postgres SET search_path TO public, extensions;
ALTER DATABASE postgres SET search_path TO public, extensions;

-- 6. REALTIME PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE public.sponsors;

-- API-Cache neu laden
NOTIFY pgrst, 'reload schema';
