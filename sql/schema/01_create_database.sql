/*
==============================================================================
  Olist Marketplace Analytics — Database Bootstrap
  Engine: PostgreSQL 14+
------------------------------------------------------------------------------
  Option A (psql): run this file as a superuser.
  Option B: create the database manually, then run the schema statements below
            while connected to olist_analytics.
==============================================================================
*/

-- Option A: create database if missing (psql meta-command)
SELECT 'CREATE DATABASE olist_analytics
        WITH OWNER = CURRENT_USER
             ENCODING = ''UTF8''
             TEMPLATE = template0'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'olist_analytics')\gexec

\connect olist_analytics

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS ecommerce;
CREATE SCHEMA IF NOT EXISTS marketing;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA staging   IS 'Raw landing zone for CSV ingestion';
COMMENT ON SCHEMA ecommerce IS 'Cleaned e-commerce relational model';
COMMENT ON SCHEMA marketing IS 'Seller acquisition marketing funnel';
COMMENT ON SCHEMA analytics IS 'Star-schema analytical layer for reporting';
