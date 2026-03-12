-- 1. ROLLEN & RECHTE ZURÜCKSETZEN
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
END
$$;

-- Dem Admin erlauben, alles zu tun
ALTER USER postgres WITH SUPERUSER;

-- 2. SCHEMA EINRICHTEN
CREATE SCHEMA IF NOT EXISTS public;
GRANT USAGE ON SCHEMA public TO anon;
ALTER SCHEMA public OWNER TO postgres;

-- 3. TABELLEN (SAUBERER NEUSTART)
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
-- Wir geben dem anon-User VOLLZUGRIFF auf die Tabellen
ALTER TABLE public.sponsors OWNER TO postgres;
ALTER TABLE public.project_settings OWNER TO postgres;

GRANT SELECT, INSERT, UPDATE ON public.sponsors TO anon;
GRANT SELECT ON public.project_settings TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- RLS ausschalten (für den Test, damit nichts blockiert)
ALTER TABLE public.sponsors DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_settings DISABLE ROW LEVEL SECURITY;

-- Suchpfad für alle festlegen
ALTER ROLE anon SET search_path TO public;
ALTER ROLE postgres SET search_path TO public;

-- 5. REALTIME (FALLS BENÖTIGT)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE public.sponsors;
COMMIT;
