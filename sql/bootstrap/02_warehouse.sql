\connect warehouse

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS deid;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

\set etl_password `printf '%s' "$ETL_PASSWORD"`
\set dbt_password `printf '%s' "$DBT_PASSWORD"`
\set tableau_password `printf '%s' "$TABLEAU_PASSWORD"`

SELECT format('CREATE ROLE etl_user LOGIN PASSWORD %L', :'etl_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'etl_user') \gexec

SELECT format('CREATE ROLE dbt_user LOGIN PASSWORD %L', :'dbt_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dbt_user') \gexec

SELECT format('CREATE ROLE tableau_user LOGIN PASSWORD %L', :'tableau_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tableau_user') \gexec

-- Landing table for raw FHIR JSON, written by airflow/pipeline/extract_load.py
CREATE TABLE IF NOT EXISTS raw.fhir_resources (
    resource_type TEXT        NOT NULL,
    resource_id   TEXT        NOT NULL,
    last_updated  TIMESTAMPTZ,
    payload       JSONB       NOT NULL,
    extracted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (resource_type, resource_id)
);

GRANT CONNECT ON DATABASE warehouse TO etl_user, dbt_user, tableau_user;
GRANT USAGE, CREATE ON SCHEMA raw, deid, staging, marts TO etl_user, dbt_user;
GRANT USAGE ON SCHEMA marts TO tableau_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA raw TO etl_user;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO dbt_user;  -- dbt reads the raw source
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA deid, staging, marts TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT, INSERT, UPDATE ON TABLES TO etl_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT ON TABLES TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA marts GRANT SELECT ON TABLES TO tableau_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_user IN SCHEMA marts GRANT SELECT ON TABLES TO tableau_user;
