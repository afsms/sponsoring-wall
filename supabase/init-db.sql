-- 1. ROLLEN & BASIS
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END $$;
GRANT anon TO postgres;

-- 2. SCHEMAS
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS public;

-- 3. TABELLEN (Erzwungen in beiden Schemas)
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

-- Kopie in api schema
CREATE TABLE IF NOT EXISTS api.sponsors AS TABLE public.sponsors WITH NO DATA;
INSERT INTO api.sponsors SELECT * FROM public.sponsors ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS api.project_settings AS TABLE public.project_settings WITH NO DATA;
INSERT INTO api.project_settings SELECT * FROM public.project_settings ON CONFLICT DO NOTHING;

-- Seed falls leer
INSERT INTO public.project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM public.project_settings);

-- 4. BERECHTIGUNGEN (RADIKAL)
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA api TO anon;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA api TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO anon;

-- 5. SUCHPFAD
ALTER ROLE anon SET search_path TO api, public;
ALTER DATABASE postgres SET search_path TO api, public;

-- 6. CACHE RELOAD
NOTIFY pgrst, 'reload schema';
