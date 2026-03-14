#!/bin/sh
set -e
export PGPASSWORD=${POSTGRES_PASSWORD}

echo "Warte auf Datenbank..."
sleep 3

psql -h db -U postgres -d postgres <<-EOSQL
  INSERT INTO public.tenants (id, name, external_id, jwt_secret, inserted_at, updated_at)
  VALUES (
    gen_random_uuid(),
    'realtime',
    'realtime',
    '6dKW9oWJovUKuzndQjo5aIRnIXzg/T+MB6MtS6f7ztyTNOkR9wV/bWOD445edIUxa4YbSoI2XQvsUSxmW7AtmmWaGbKwOf6NFjwPaxKyA9Y=',
    now(),
    now()
  )
  ON CONFLICT (external_id) DO UPDATE SET
    jwt_secret = EXCLUDED.jwt_secret,
    updated_at = now();

  INSERT INTO public.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at)
  VALUES (
    gen_random_uuid(),
    'postgres_cdc_rls',
    '{
      "db_host": "q3tdZ2illYUrNymyi4O5nw==",
      "db_port": "e3mOh7fcqD+zkwED48Qd0Q==",
      "db_name": "FeiFHl6FFDxnEgF/PUIwLA==",
      "db_user": "FeiFHl6FFDxnEgF/PUIwLA==",
      "db_password": "yH9sL/+lF+p0M54q2THPhrQovj4IKZauug7k51JPJ5hlmhmysDn+jRY8D2sSsgPW",
      "db_ssl": false,
      "ssl_enforced": false,
      "region": "eu-west-1",
      "publication": "supabase_realtime",
      "slot_name": "supabase_realtime_replication_slot",
      "poll_interval_ms": 100,
      "poll_max_changes": 100,
      "poll_max_record_bytes": 1048576
    }',
    'realtime',
    now(),
    now()
  )
  ON CONFLICT DO NOTHING;
EOSQL

echo "✅ Realtime Tenant konfiguriert."
