resource "aws_instance" "api_gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.api_gateway.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Setup 2GB Swap Memory
              dd if=/dev/zero of=/swapfile bs=128M count=16
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

              # Wait for NAT to be available
              until ping -c 1 8.8.8.8; do
                echo "Waiting for NAT instance to be ready..."
                sleep 5
              done

              # Install and start SSM Agent
              dnf install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent

              # Install Docker and Docker Compose
              dnf install docker -y
              systemctl enable docker
              systemctl start docker
              mkdir -p /usr/local/lib/docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # API Gateway container will be started here (Placeholder)
              # docker run -d --name api-gateway ...
              EOF

  depends_on = [
    aws_route.private_nat_route
  ]

  tags = {
    Name = "quietchatter-api-gateway-node"
  }
}
