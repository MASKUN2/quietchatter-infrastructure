# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "quietchatter-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "quietchatter-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "quietchatter-public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "quietchatter-private-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "quietchatter-public-rt"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "quietchatter-private-rt"
  }
}

# Private Route Table Association
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# NAT Resources
resource "aws_network_interface" "nat_eni" {
  subnet_id         = aws_subnet.public[0].id
  private_ips       = [var.nat_private_ip]
  security_groups   = [aws_security_group.nat.id]
  source_dest_check = false # Critical for NAT functionality

  tags = {
    Name = "quietchatter-nat-eni"
  }
}

resource "aws_instance" "nat" {
  ami           = var.ami_id
  instance_type = "t4g.nano"

  user_data_replace_on_change = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  network_interface {
    network_interface_id = aws_network_interface.nat_eni.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/templates/nat_user_data.sh.tftpl", {
    vpc_cidr = var.vpc_cidr
  })

  tags = {
    Name = "quietchatter-nat-node"
  }

  # Ensure IGW is ready before NAT instance tries to connect to internet
  depends_on = [aws_internet_gateway.igw]
}

# Default route for private subnets via NAT instance
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.nat_eni.id
}

resource "aws_eip" "nat" {
  domain            = "vpc"
  network_interface = aws_network_interface.nat_eni.id

  tags = {
    Name = "quietchatter-nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

# S3 Assets Bucket
resource "aws_s3_bucket" "infra_assets" {
  bucket = "quietchatter-infra-assets"

  tags = {
    Name = "quietchatter-infra-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "infra_assets" {
  bucket = aws_s3_bucket.infra_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
