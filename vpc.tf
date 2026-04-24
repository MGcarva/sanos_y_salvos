# ================================================================
# VPC - Red privada virtual principal
# Contiene todos los recursos de Sanos y Salvos en AWS
# ================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # Necesario para que RDS tenga hostname DNS
  enable_dns_support   = true

  tags = {
    Name     = "${var.proyecto}-vpc"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

# ================================================================
# SUBNETS PÚBLICAS — 2 zonas de disponibilidad
# Aquí vive el ALB (Application Load Balancer)
# Los recursos aquí reciben IP pública automáticamente
# ================================================================

resource "aws_subnet" "publica_az_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name     = "${var.proyecto}-subnet-publica-az-a"
    Tipo     = "publica"
    Proyecto = var.proyecto
  }
}

resource "aws_subnet" "publica_az_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name     = "${var.proyecto}-subnet-publica-az-b"
    Tipo     = "publica"
    Proyecto = var.proyecto
  }
}

# ================================================================
# SUBNETS PRIVADAS — 2 zonas de disponibilidad
# Aquí viven: ECS (contenedores), RDS, ElastiCache Redis
# Sin acceso directo desde internet
# ================================================================

resource "aws_subnet" "privada_az_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name     = "${var.proyecto}-subnet-privada-az-a"
    Tipo     = "privada"
    Proyecto = var.proyecto
  }
}

resource "aws_subnet" "privada_az_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name     = "${var.proyecto}-subnet-privada-az-b"
    Tipo     = "privada"
    Proyecto = var.proyecto
  }
}

# ================================================================
# INTERNET GATEWAY
# Puerta de entrada/salida hacia internet para las subnets públicas
# ================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name     = "${var.proyecto}-igw"
    Proyecto = var.proyecto
  }
}

# ================================================================
# NAT GATEWAY
# Permite que los contenedores en subnets privadas salgan a internet
# (necesario para descargar imágenes ECR, llamar APIs externas)
# Solo 1 NAT en AZ-a para reducir costos en AWS Academy
# ================================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name     = "${var.proyecto}-eip-nat"
    Proyecto = var.proyecto
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.publica_az_a.id   # NAT va en subnet PÚBLICA

  tags = {
    Name     = "${var.proyecto}-nat-gateway"
    Proyecto = var.proyecto
  }

  depends_on = [aws_internet_gateway.main]
}

# ================================================================
# TABLA DE RUTAS PÚBLICA
# Todo el tráfico de subnets públicas sale por el Internet Gateway
# ================================================================

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name     = "${var.proyecto}-rt-publica"
    Proyecto = var.proyecto
  }
}

# Asociar ambas subnets públicas a la tabla de rutas pública
resource "aws_route_table_association" "publica_az_a" {
  subnet_id      = aws_subnet.publica_az_a.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "publica_az_b" {
  subnet_id      = aws_subnet.publica_az_b.id
  route_table_id = aws_route_table.publica.id
}

# ================================================================
# TABLA DE RUTAS PRIVADA
# El tráfico saliente de subnets privadas pasa por el NAT Gateway
# (no hay entrada directa desde internet)
# ================================================================

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name     = "${var.proyecto}-rt-privada"
    Proyecto = var.proyecto
  }
}

# Asociar ambas subnets privadas a la tabla de rutas privada
resource "aws_route_table_association" "privada_az_a" {
  subnet_id      = aws_subnet.privada_az_a.id
  route_table_id = aws_route_table.privada.id
}

resource "aws_route_table_association" "privada_az_b" {
  subnet_id      = aws_subnet.privada_az_b.id
  route_table_id = aws_route_table.privada.id
}
