# Control Plane Data Volume
resource "aws_ebs_volume" "controlplane_data" {
  availability_zone = var.azs[0]
  size              = 15
  type              = "gp3"

  lifecycle {
    prevent_destroy = true
  }

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

# Control Plane Node
resource "aws_instance" "controlplane" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.controlplane_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.controlplane_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
  })

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "quietchatter-controlplane-node"
  }
}

# Platform Node (Redpanda only)
resource "aws_instance" "platform" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.platform_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.microservices_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/platform_user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    k3s_server_ip    = aws_instance.controlplane.private_ip
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "quietchatter-platform-node"
  }
}

# RDS Resources
resource "aws_db_subnet_group" "main" {
  name       = "quietchatter-db-subnet-group"
  subnet_ids = data.terraform_remote_state.base.outputs.private_subnet_ids

  tags = {
    Name = "quietchatter-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "quietchatter-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  db_name  = "quietchatter"
  username = data.terraform_remote_state.base.outputs.db_username
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.rds_sg_id]

  multi_az          = false
  availability_zone = var.azs[0]

  backup_retention_period = 7
  backup_window           = "18:00-19:00"
  maintenance_window      = "Mon:19:00-Mon:20:00"

  deletion_protection = true
  skip_final_snapshot = true

  tags = {
    Name = "quietchatter-db"
  }
}
