#!/bin/sh
set -e
export PGPASSWORD=qZ7_pX92_mK4_vL1_sR8_db_pass

psql -h db -U postgres -d postgres <<-EOSQL
  INSERT INTO public.tenants (id, name, external_id, jwt_secret, inserted_at, updated_at)
  VALUES (
    '3cad861d-0162-4f72-af23-087b2eb569cd',
    'realtime',
    'realtime',
    'iFzSsdJQ67DLzVapJn8bbVZxEmQVXMFx309zlrJSbj8dePnPHbT5Ve/d9fGlk48MrOIRaR51HrKovkLe3SBD3A==',
    now(),
    now()
  )
  ON CONFLICT (external_id) DO UPDATE SET
    jwt_secret = EXCLUDED.jwt_secret,
    updated_at = now();
EOSQL