-- This script runs after the main POSTGRES_DB is created.
-- It creates an additional database for Metabase metadata.
CREATE DATABASE metabase;
GRANT ALL PRIVILEGES ON DATABASE metabase TO bi_user;  -- use your actual user