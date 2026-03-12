-- Make postgres a superuser so Realtime migrations can create tables in the realtime schema
-- This runs as z99-init-db.sql AFTER Supabase base migrations (which create supabase_admin)
ALTER USER postgres WITH SUPERUSER;

-- Transfer realtime schema ownership to postgres for Realtime migrations
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

CREATE TABLE IF NOT EXISTS sponsors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    sq_meters NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    iban VARCHAR(255),
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Permissions
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Realtime Publication
ALTER PUBLICATION supabase_realtime ADD TABLE sponsors;

-- Settings
CREATE TABLE IF NOT EXISTS project_settings (
    id SERIAL PRIMARY KEY,
    goal_sq_meters NUMERIC(10, 2) DEFAULT 2480,
    price_per_unit NUMERIC(10, 2) DEFAULT 15.15,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO project_settings (goal_sq_meters, price_per_unit) 
SELECT 2480, 15.15 WHERE NOT EXISTS (SELECT 1 FROM project_settings);

GRANT SELECT on project_settings TO anon;
