resource "aws_network_interface" "nat_ingress_eni" {
  subnet_id         = aws_subnet.public[0].id
  security_groups   = [aws_security_group.nat_ingress.id]
  source_dest_check = false # Critical for NAT functionality

  tags = {
    Name = "quietchatter-nat-ingress-eni"
  }
}

resource "aws_instance" "nat_ingress" {
  ami           = var.ami_id
  instance_type = "t4g.nano"

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  network_interface {
    network_interface_id = aws_network_interface.nat_ingress_eni.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              # Setup 2GB Swap Memory
              dd if=/dev/zero of=/swapfile bs=128M count=16
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

              # Install and start SSM Agent
              dnf install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent

              # Enable IP Forwarding for NAT
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              
              # Set up iptables for NAT
              yum install iptables-services -y
              systemctl enable iptables
              systemctl start iptables
              iptables -t nat -A POSTROUTING -o enX0 -j MASQUERADE
              iptables-save > /etc/sysconfig/iptables

              # Install Docker and Docker Compose
              dnf install docker -y
              systemctl enable docker
              systemctl start docker
              mkdir -p /usr/local/lib/docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Create docker-compose.yaml from external file
              cat <<EOT > /home/ec2-user/docker-compose.yaml
              ${file("${path.module}/templates/docker-compose.nat-ingress.yaml")}
              EOT

              # Run containers
              cd /home/ec2-user
              docker compose up -d
              EOF

  tags = {
    Name = "quietchatter-nat-ingress-node"
  }
}

# Route internal traffic to the NAT Instance
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.nat_ingress_eni.id
}
