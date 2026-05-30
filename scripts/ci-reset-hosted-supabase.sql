-- Reset the hosted Supabase test project before applying backend seed.sql.
--
-- The app under test receives only the anon key. This SQL runs separately via
-- CI_SUPABASE_DB_URL and may use privileged database access.

BEGIN;

SET LOCAL search_path = public, auth, extensions;

-- Clear app-owned data. Reference rows are recreated by ios-app-backend's
-- seed.sql so the backend repo remains the single source of seed truth.
DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'notifications',
    'user_badges',
    'likes',
    'pins',
    'device_tokens',
    'moments',
    'friendships',
    'posts',
    'profiles',
    'badge_types'
  ]
  LOOP
    IF to_regclass('public.' || quote_ident(table_name)) IS NOT NULL THEN
      EXECUTE format('DELETE FROM public.%I', table_name);
    END IF;
  END LOOP;
END $$;

-- Clear Auth state after public rows so profile foreign keys cascade cleanly.
DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'refresh_tokens',
    'mfa_amr_claims',
    'mfa_challenges',
    'mfa_factors',
    'one_time_tokens',
    'sessions',
    'identities',
    'users'
  ]
  LOOP
    IF to_regclass('auth.' || quote_ident(table_name)) IS NOT NULL THEN
      EXECUTE format('DELETE FROM auth.%I', table_name);
    END IF;
  END LOOP;
END $$;

COMMIT;
