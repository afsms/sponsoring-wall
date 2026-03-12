#!/bin/sh
# Diese Variablen kommen in der Produktion aus deinem Secret Manager (Vault, AWS Secrets, etc.)
# JWT_SECRET und REALTIME_ENCRYPTION_KEY müssen gesetzt sein.

# 1. Extrahiere die Keys (oder nutze die bereits gesetzten ENV-Variablen)
JWT_SECRET=${JWT_SECRET:-"12345678901234567890123456789012"}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgrespassword"}
REALTIME_ENCRYPTION_KEY=${REALTIME_ENCRYPTION_KEY:-"1234567890123456"}

export PGPASSWORD=$POSTGRES_PASSWORD

# 2. Führe das SQL direkt beim Start der Datenbank aus
psql -v ON_ERROR_STOP=1 -h db -U postgres -d postgres <<-EOF


DO \$\$ 
BEGIN
    DELETE FROM public.extensions;
    DELETE FROM public.tenants;

    -- Wir fügen den Tenant ein. Nutze vorberechnete AES-ECB Base64 Hashes
    INSERT INTO public.tenants (id, name, external_id, jwt_secret, presence_enabled, inserted_at, updated_at) 
    VALUES (
        '3cad861d-0162-4f72-af23-087b2eb569cd', 
        'realtime', 
        'realtime', 
        'dXzNDNxckOrb7uz2ON0AAMa/oq6BhXPyhbLV8HHxnGcFAYegzeWphyy6sJGrc+VT', 
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (external_id) DO UPDATE SET jwt_secret = EXCLUDED.jwt_secret, updated_at = NOW();

    INSERT INTO public.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at) 
    VALUES (
        '3cad861d-0162-4f72-af23-087b2eb569cf', 
        'postgres_cdc_rls', 
        jsonb_build_object(
            'db_host', 'O0bymVcPkBJkHbQfmk2SxQ==',
            'db_name', 'v1QVng3N+pZd/0AEObABwg==',
            'db_user', 'v1QVng3N+pZd/0AEObABwg==',
            'db_password', 'AdENA55Koette5Up5WH3LwUBh6DN5amHLLqwkatz5VM=',
            'db_port', 'm3KM2cjJ+t7C3443QcjOgA==',
            'ssl_enforced', false,
            'poll_interval_ms', 100,
            'poll_max_changes', 100,
            'poll_max_record_bytes', 1048576,
            'publication', 'supabase_realtime',
            'slot_name', 'supabase_realtime_replication_slot'
        ),
        'realtime',
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET settings = EXCLUDED.settings, updated_at = NOW();
END \$\$;
EOF
