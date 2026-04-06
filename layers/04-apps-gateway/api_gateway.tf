locals {
  # Alloy 및 Docker Compose 설정을 미리 렌더링하여 가독성 개선
  alloy_config = templatefile("${path.module}/templates/config.alloy.tftpl", {
    instance_name = "quietchatter-api-gateway-node"
    loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  docker_compose_config = templatefile("${path.module}/templates/docker-compose.gateway.yaml.tftpl", {
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.api_gateway_image
  })
}

resource "aws_instance" "api_gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.api_gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.api_gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  # userdata 변경 시 인스턴스를 자동으로 교체하여 설정 반영
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                  = var.aws_region
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    alloy_config                = local.alloy_config
    docker_compose_config       = local.docker_compose_config
  })

  tags = {
    Name = "quietchatter-api-gateway-node"
  }
}

output "api_gateway_private_ip" {
  value = aws_instance.api_gateway.private_ip
}
