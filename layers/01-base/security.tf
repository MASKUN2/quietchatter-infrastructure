# NAT / Ingress Security Group
resource "aws_security_group" "nat_ingress" {
  name        = "quietchatter-nat-ingress-sg"
  description = "Security group for NAT and NGINX Ingress"
  vpc_id      = aws_vpc.main.id

  # HTTP/HTTPS for NGINX
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal traffic from VPC for NAT purpose
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-nat-ingress-sg"
  }
}

# API Gateway Security Group
resource "aws_security_group" "api_gateway" {
  name        = "quietchatter-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nat_ingress.id]
  }

  ingress {
    from_port       = 80
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Consul Serf LAN (Internal)
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-api-gateway-sg"
  }
}

# Microservices Security Group
resource "aws_security_group" "microservices" {
  name        = "quietchatter-microservices-sg"
  description = "Security group for internal microservices"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    security_groups = [
      aws_security_group.api_gateway.id
    ]
  }

  # Allow all internal traffic from VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-microservices-sg"
  }
}

# Frontend (Next.js BFF) Security Group
resource "aws_security_group" "frontend" {
  name        = "quietchatter-frontend-sg"
  description = "Security group for Next.js BFF"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.nat_ingress.id]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-frontend-sg"
  }
}

# Control Plane Node Security Group
resource "aws_security_group" "controlplane" {
  name        = "quietchatter-controlplane-sg"
  description = "Security group for Control Plane (DB, Kafka, Redis, Consul)"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.api_gateway.id
    ]
  }

  # Redis
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.api_gateway.id
    ]
  }

  # Redpanda (Kafka)
  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.api_gateway.id
    ]
  }

  ingress {
    from_port       = 19092
    to_port         = 19092
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.api_gateway.id
    ]
  }

  ingress {
    from_port       = 9644
    to_port         = 9644
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.api_gateway.id
    ]
  }

  # Consul UI & API (from within VPC)
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Consul RPC & Serf
  ingress {
    from_port   = 8300
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-controlplane-sg"
  }
}
