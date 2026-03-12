-- 1. ROLLEN-SETUP (Supabase-kompatibel)
-- Wir stellen sicher, dass die Rollen existieren und die richtigen Attribute haben
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

-- WICHTIG: Erlaube dem Admin-User die Identität der Rollen anzunehmen
GRANT anon TO postgres;
GRANT authenticated TO postgres;

-- 2. SCHEMA-REINIGUNG
CREATE SCHEMA IF NOT EXISTS public;
ALTER SCHEMA public OWNER TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 3. TABELLEN (NEU ANLEGEN)
DROP TABLE IF EXISTS public.sponsors CASCADE;
CREATE TABLE public.sponsors (
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

DROP TABLE IF EXISTS public.project_settings CASCADE;
CREATE TABLE public.project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC(10, 2) DEFAULT 2480,
    price_per_unit NUMERIC(10, 2) DEFAULT 15.15,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) VALUES (2480, 15.15);

-- 4. BERECHTIGUNGEN (DER ENTSCHEIDENDE TEIL)
-- Wir geben anon explizit ALLE Rechte für den Test
GRANT ALL ON public.sponsors TO anon;
GRANT ALL ON public.project_settings TO anon;
GRANT ALL ON public.sponsors TO authenticated;
GRANT ALL ON public.project_settings TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Suchpfad für die Session erzwingen
ALTER ROLE anon SET search_path TO public, extensions;
ALTER ROLE postgres SET search_path TO public, extensions;
ALTER DATABASE postgres SET search_path TO public, extensions;

-- Statistiken aktualisieren, damit PostgREST nicht verwirrt ist
ANALYZE public.sponsors;
ANALYZE public.project_settings;

-- 5. REALTIME
DO $$
BEGIN
    DROP PUBLICATION IF EXISTS supabase_realtime;
    CREATE PUBLICATION supabase_realtime FOR TABLE public.sponsors;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Publication setup failed, but continuing...';
END $$;
