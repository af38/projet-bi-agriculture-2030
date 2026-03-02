-- Contraintes et index (format PostgreSQL)
SELECT
  n.nspname AS schema,
  c.relname AS table,
  con.conname AS constraint_name,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','staging')
ORDER BY schema, table, constraint_name;

-- Index
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname IN ('public','staging')
ORDER BY schemaname, tablename, indexname;
