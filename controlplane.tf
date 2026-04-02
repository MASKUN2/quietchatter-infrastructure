resource "aws_ebs_volume" "controlplane_data" {
  availability_zone = var.azs[0]
  size              = 15
  type              = "gp3"

  tags = {
    Name = "quietchatter-controlplane-data"
  }
}

resource "aws_volume_attachment" "controlplane_att" {
  device_name  = "/dev/sdb"
  volume_id    = aws_ebs_volume.controlplane_data.id
  instance_id  = aws_instance.controlplane.id
  force_detach = true
}

resource "aws_instance" "controlplane" {
  ami           = var.ami_id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.controlplane.id]
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

              # Wait for the EBS volume to be attached
              while [ ! -b /dev/nvme1n1 ]; do echo "Waiting for /dev/nvme1n1..."; sleep 2; done

              # Create file system if it doesn't exist
              if ! blkid /dev/nvme1n1; then
                mkfs -t xfs /dev/nvme1n1
              fi

              # Mount the volume
              mkdir -p /data
              mount /dev/nvme1n1 /data
              echo "/dev/nvme1n1 /data xfs defaults,nofail 0 2" >> /etc/fstab

              # Install Docker and Docker Compose
              dnf install docker -y
              systemctl enable docker
              systemctl start docker
              mkdir -p /usr/local/lib/docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Create docker-compose.yaml on the mounted volume
              mkdir -p /data/app
              cat <<EOT > /data/app/docker-compose.yaml
              ${file("${path.module}/templates/docker-compose.controlplane.yaml")}
              EOT

              # Run containers from the mounted volume
              cd /data/app
              docker compose up -d
              EOF

  # Protection against accidental deletion
  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates to prevent data downtime
  }

  depends_on = [
    aws_route.private_nat_route
  ]

  tags = {
    Name = "quietchatter-controlplane-node"
  }
}
