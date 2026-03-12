-- Make postgres a superuser so Realtime migrations can create tables in the realtime schema
ALTER USER postgres WITH SUPERUSER;

-- Transfer realtime schema ownership to postgres
ALTER SCHEMA realtime OWNER TO postgres;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
END
$$;

-- Schema and Tables
CREATE SCHEMA IF NOT EXISTS public;

-- Corrected sponsors table to match Register.jsx
CREATE TABLE IF NOT EXISTS sponsors (
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

-- Settings
CREATE TABLE IF NOT EXISTS project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC(10, 2) DEFAULT 2480,
    price_per_unit NUMERIC(10, 2) DEFAULT 15.15,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM project_settings);

-- Permissions
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT ON public.sponsors TO anon;
GRANT SELECT ON public.project_settings TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Realtime Publication
-- Note: Publication might already exist, so we use a safe way to add the table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE sponsors;
