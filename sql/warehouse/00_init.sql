-- Warehouse = BigQuery stand-in. Files land on disk; tables live here.
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS ops;

-- Diary of loads (the watermark). SUCCESS rows only after files exist.
CREATE TABLE IF NOT EXISTS ops.audit_log (
  audit_id BIGSERIAL PRIMARY KEY,
  tablename TEXT NOT NULL,
  load_type TEXT NOT NULL,
  record_count INT,
  load_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ops.pipeline_logs (
  log_id BIGSERIAL PRIMARY KEY,
  logged_at TIMESTAMP NOT NULL DEFAULT NOW(),
  event_type TEXT NOT NULL,
  message TEXT NOT NULL,
  tablename TEXT
);
