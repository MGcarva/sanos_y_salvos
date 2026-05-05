# ================================================================
# RDS — PostgreSQL 15 con soporte PostGIS
# Una sola instancia que contiene las 4 bases de datos:
#   auth_db | mascotas_db | geolocalizacion_db | coincidencias_db
#
# NOTA IMPORTANTE — Inicialización de las BDs:
# RDS arranca con solo la BD "postgres" por defecto.
# Las 4 BDs y sus extensiones se crean ejecutando el script
# init-db.sql DESPUÉS de que los contenedores ECS estén corriendo.
# Ver instrucciones al final de este archivo.
# ================================================================

# ================================================================
# SUBNET GROUP
# Le dice a RDS en qué subnets puede desplegarse
# Necesita mínimo 2 subnets en AZs distintas (requisito de AWS)
# ================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${var.proyecto}-db-subnet-group-new"
  description = "Subnet group para RDS PostgreSQL en 2 AZs"
  subnet_ids  = [
    aws_subnet.privada_az_a.id,
    aws_subnet.privada_az_b.id
  ]

  tags = {
    Name     = "${var.proyecto}-db-subnet-group"
    Proyecto = var.proyecto
  }

  # lifecycle {
  #   ignore_changes = [subnet_ids]
  # }
}

# import {
#   to = aws_db_subnet_group.main
#   id = "sanos-y-salvos-db-subnet-group-v2"
# }

# ================================================================
# PARAMETER GROUP
# Configuración del motor PostgreSQL 15
# Necesario para habilitar extensiones como postgis y pg_trgm
# ================================================================

resource "aws_db_parameter_group" "postgres15" {
  name        = "${var.proyecto}-pg15-new"
  family      = "postgres15"
  description = "Parameter group para PostgreSQL 15 con soporte PostGIS"

  # Necesario para que PostGIS y pg_trgm funcionen correctamente
  parameter {
    name  = "rds.force_ssl"
    value = "0"   # Desactivado en Academy para simplificar conexiones
  }

  tags = {
    Name     = "${var.proyecto}-pg15"
    Proyecto = var.proyecto
  }
}

# import {
#   to = aws_db_parameter_group.postgres15
#   id = "sanos-y-salvos-pg15"
# }

# ================================================================
# INSTANCIA RDS
# Una sola instancia db.t3.micro (dentro del límite de Academy)
# Contiene las 4 bases de datos como databases separadas
# ================================================================

resource "aws_db_instance" "main" {
  identifier = "${var.proyecto}-postgres-new"

  # Motor y versión
  engine         = "postgres"
  engine_version = "15.10"
  instance_class = var.db_instance_class   # db.t3.micro

  # Base de datos inicial (postgres = BD por defecto del sistema)
  # Las 4 BDs del proyecto se crean con init-db.sql después del deploy
  db_name  = "postgres"
  username = var.db_username
  password = var.db_password

  # Almacenamiento
  allocated_storage     = 20          # GB — mínimo en RDS, dentro de Free Tier
  max_allocated_storage = 20          # Sin auto-scaling de storage en Academy
  storage_type          = "gp2"
  storage_encrypted     = true        # Cifrado en reposo

  # Red y seguridad
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres15.name
  publicly_accessible    = false      # NUNCA exponer RDS a internet

  # Alta disponibilidad
  # multi_az = false en Academy — el subnet group de 2 AZs
  # garantiza que RDS puede moverse entre AZs si hay fallo,
  # pero no corre réplica activa simultánea (ahorras costos)
  multi_az = false

  # Backups
  backup_retention_period = 1         # 1 día es suficiente en Academy
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Configuración para facilitar el uso en Academy
  skip_final_snapshot = true          # Permite hacer terraform destroy sin snapshot
  deletion_protection = false         # Permite eliminar la instancia libremente

  # Actualizaciones automáticas de versiones menores
  auto_minor_version_upgrade = true

  tags = {
    Name     = "${var.proyecto}-postgres"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

# ================================================================
# OUTPUTS — El endpoint de RDS se usa en ecs.tf como DB_HOST
# ================================================================

output "rds_endpoint" {
  description = "Endpoint de RDS — se usa como DB_HOST en las variables de entorno de ECS"
  value       = aws_db_instance.main.address   # Solo el hostname, sin el puerto
}

output "rds_port" {
  description = "Puerto de PostgreSQL"
  value       = aws_db_instance.main.port
}

# ================================================================
# INSTRUCCIONES POST-DEPLOY — Inicializar las 4 bases de datos
#
# Después de ejecutar terraform apply, conectarse a uno de los
# contenedores ECS que ya estén corriendo y ejecutar:
#
#   aws ecs execute-command \
#     --cluster sanos-y-salvos \
#     --task <TASK_ID> \
#     --container auth-service \
#     --interactive \
#     --command "/bin/sh"
#
# Dentro del contenedor, ejecutar:
#   psql -h <RDS_ENDPOINT> -U sanosadmin -d postgres -f /init-db.sql
#
# O conectarse directamente con psql si tienes acceso desde tu red:
#   psql -h <RDS_ENDPOINT> -U sanosadmin -d postgres
#   Luego pegar el contenido de scripts/init-db.sql
#
# Las tablas las crea Hibernate automáticamente al arrancar
# cada microservicio (ddl-auto: update en application.yml)
# ================================================================
