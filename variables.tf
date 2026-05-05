# Las variables nos permiten reutilizar valores sin repetirlos en todo el código.
# Piensa en ellas como parámetros de una función — defines el nombre y tipo aquí,
# y usas el valor en los archivos .tf con la sintaxis var.nombre_variable

variable "proyecto" {
  description = "Nombre del proyecto, se usa como prefijo en todos los recursos"
  type        = string
  default     = "sanos-y-salvos"
}

variable "ambiente" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "Región AWS — obligatoria en AWS Academy"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Rango de IPs de la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

# ================================================================
# VARIABLES DE BASE DE DATOS (RDS)
# ================================================================

variable "db_username" {
  description = "Usuario administrador de PostgreSQL"
  type        = string
  default     = "sanosadmin"
}

variable "db_password" {
  description = "Contraseña del administrador de PostgreSQL"
  type        = string
  sensitive   = true
  default     = "SanosYSalvos2026!"
}

variable "db_instance_class" {
  description = "Tipo de instancia RDS — db.t3.micro es elegible para Free Tier en Academy"
  type        = string
  default     = "db.t3.micro"
}

# ================================================================
# VARIABLES DE CACHE (ElastiCache Redis)
# ================================================================

variable "redis_node_type" {
  description = "Tipo de nodo Redis — cache.t3.micro para Academy"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_password" {
  description = "Contraseña de autenticación Redis"
  type        = string
  sensitive   = true
  default     = "SanosRedis2026!"
}

# ================================================================
# VARIABLES DE JWT Y SEGURIDAD
# ================================================================

variable "jwt_secret" {
  description = "Clave secreta para firmar tokens JWT"
  type        = string
  sensitive   = true
  default     = "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970"
}


