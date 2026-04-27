# NAT Security Group (Dedicated for NAT Instance)
resource "aws_security_group" "nat" {
  name        = "quietchatter-nat-sg"
  description = "Security group for dedicated NAT instance"
  vpc_id      = aws_vpc.main.id

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
    Name = "quietchatter-nat-sg"
  }
}

# Gateway Security Group (NGINX + Spring Cloud Gateway, co-located on public subnet)
resource "aws_security_group" "gateway" {
  name        = "quietchatter-gateway-sg"
  description = "Security group for Gateway node (NGINX + Spring Cloud Gateway)"
  vpc_id      = aws_vpc.main.id

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

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-gateway-sg"
  }
}

# Microservices Security Group
resource "aws_security_group" "microservices" {
  name        = "quietchatter-microservices-sg"
  description = "Security group for internal microservices (k3s worker node)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    security_groups = [
      aws_security_group.gateway.id
    ]
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
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

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "quietchatter-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.controlplane.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-rds-sg"
  }
}

# Control Plane Node Security Group
resource "aws_security_group" "controlplane" {
  name        = "quietchatter-controlplane-sg"
  description = "Security group for Control Plane (k3s server, Kafka, Redis)"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  # Redis
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  # Redpanda (Kafka)
  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  ingress {
    from_port       = 19092
    to_port         = 19092
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  ingress {
    from_port       = 9644
    to_port         = 9644
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  # Redpanda Schema Registry
  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  ingress {
    from_port       = 18081
    to_port         = 18081
    protocol        = "tcp"
    security_groups = [
      aws_security_group.microservices.id,
      aws_security_group.gateway.id
    ]
  }

  # k3s API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
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
