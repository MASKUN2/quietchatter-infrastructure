locals {
  # Alloy 및 Docker Compose 설정을 미리 렌더링하여 가독성 개선
  alloy_config = templatefile("${path.module}/templates/config.alloy.tftpl", {
    instance_name = "quietchatter-controlplane-node"
    loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  docker_compose_config = templatefile("${path.module}/templates/docker-compose.controlplane.yaml.tftpl", {
    db_username = data.terraform_remote_state.base.outputs.db_username
  })
}

# 데이터가 보존되어야 하는 EBS 볼륨 (인스턴스 교체와 독립적)
resource "aws_ebs_volume" "controlplane_data" {
  # 인스턴스가 위치한 첫 번째 프라이빗 서브넷의 AZ를 동적으로 참조
  availability_zone = var.azs[0]
  size              = 15
  type              = "gp3"

  # 실수로 인한 데이터 볼륨 삭제 방지
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

resource "aws_instance" "controlplane" {
  ami           = var.ami_id
  instance_type = "t4g.small"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.controlplane_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.controlplane_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  # userdata 변경 시 인스턴스를 자동으로 교체하여 설정 반영
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                  = var.aws_region
    db_password_secret_name     = data.terraform_remote_state.base.outputs.db_password_secret_name
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    alloy_config                = local.alloy_config
    init_db_sql                 = file("${path.module}/init-db.sql")
    docker_compose_config       = local.docker_compose_config
  })

  # 데이터 유실 방지를 위한 AMI 교체 무시 설정
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "quietchatter-controlplane-node"
  }
}

output "controlplane_private_ip" {
  value = aws_instance.controlplane.private_ip
}
