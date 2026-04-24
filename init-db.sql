-- ============================================================
-- Sanos y Salvos - Inicializacion de Bases de Datos
-- Ejecutar UNA SOLA VEZ contra RDS PostgreSQL 15
--
-- Las TABLAS son creadas automaticamente por Hibernate
-- (ddl-auto: update) cuando cada microservicio arranca.
-- Este script solo crea las 4 BDs y habilita extensiones.
-- ============================================================

-- Crear las 4 bases de datos
CREATE DATABASE auth_db;
CREATE DATABASE mascotas_db;
CREATE DATABASE geolocalizacion_db;
CREATE DATABASE coincidencias_db;

-- Habilitar PostGIS y pg_trgm en geolocalizacion_db
\c geolocalizacion_db
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Habilitar pg_trgm en coincidencias_db (fuzzy matching)
\c coincidencias_db
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Habilitar uuid-ossp en auth_db y mascotas_db (UUID generation)
\c auth_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c mascotas_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Volver a postgres
\c postgres
SELECT 'Inicializacion completada' AS resultado;
