resource "aws_instance" "api_gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.api_gateway.id]

  user_data = <<-EOF
              #!/bin/bash
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

  tags = {
    Name = "quietchatter-api-gateway-node"
  }
}
