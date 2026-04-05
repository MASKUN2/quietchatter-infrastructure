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
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.controlplane_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.controlplane_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                  = var.aws_region
    db_password_secret_name     = data.terraform_remote_state.base.outputs.db_password_secret_name
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    alloy_config                = templatefile("${path.module}/templates/config.alloy.tftpl", {
                                     instance_name = "quietchatter-controlplane-node"
                                     loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url                                    loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
                                  })
    init_db_sql                 = file("${path.module}/init-db.sql")
    docker_compose_config       = templatefile("${path.module}/templates/docker-compose.controlplane.yaml.tftpl", {
                                    db_username = data.terraform_remote_state.base.outputs.db_username
                                  })
  })

  # Protection against accidental deletion
  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates to prevent data downtime
  }

  # Dependency removed as it is now across layers (handled by user_data wait script)
  # depends_on = [
  #   aws_route.private_nat_route
  # ]

  tags = {
    Name = "quietchatter-controlplane-node"
  }
}

output "controlplane_private_ip" {
  value = aws_instance.controlplane.private_ip
}
