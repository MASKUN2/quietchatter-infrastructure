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

output "nat_instance_id" {
  value = aws_instance.nat.id
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}
