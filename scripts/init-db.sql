-- ============================================
-- Sanos y Salvos - Database Initialization
-- Creates all 4 databases + required extensions
-- NOTE: Tables are auto-created by Hibernate (ddl-auto: update)
-- ============================================

-- Create databases
CREATE DATABASE auth_db;
CREATE DATABASE mascotas_db;
CREATE DATABASE geolocalizacion_db;
CREATE DATABASE coincidencias_db;

-- Extensions for auth_db
\c auth_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extensions for mascotas_db
\c mascotas_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extensions for geolocalizacion_db (PostGIS required for spatial queries)
\c geolocalizacion_db;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extensions for coincidencias_db (pg_trgm required for fuzzy matching)
\c coincidencias_db;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
