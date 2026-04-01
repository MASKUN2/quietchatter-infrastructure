resource "aws_ebs_volume" "persistence_data" {
  availability_zone = var.azs[0]
  size              = 15
  type              = "gp3"

  tags = {
    Name = "quietchatter-persistence-data"
  }
}

resource "aws_volume_attachment" "persistence_att" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.persistence_data.id
  instance_id = aws_instance.persistence.id
  
  # Ensure the instance is running before attaching, 
  # but sometimes it's better to stop the instance for a clean attach.
  # For now, we'll keep it simple.
  force_detach = true
}

resource "aws_instance" "persistence" {
  ami           = var.ami_id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.persistence.id]

  user_data = <<-EOF
              #!/bin/bash
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
              ${file("${path.module}/docker-compose.persistence.yaml")}
              EOT

              # Run containers from the mounted volume
              cd /data/app
              docker compose up -d
              EOF

  # Protection against accidental deletion
  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates to prevent data downtime
  }

  tags = {
    Name = "quietchatter-persistence-node"
  }
}
