locals {
  alloy_config = templatefile("${path.module}/templates/config.alloy.tftpl", {
    instance_name = "quietchatter-frontend-node"
    loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  docker_compose_config = templatefile("${path.module}/templates/docker-compose.frontend.yaml.tftpl", {
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.frontend_image
  })
}

resource "aws_instance" "frontend" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = data.terraform_remote_state.base.outputs.frontend_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.frontend_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                      = var.aws_region
    grafana_api_key_secret_name     = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    bff_jwt_secret_name             = data.terraform_remote_state.base.outputs.bff_jwt_secret_name
    naver_client_id_secret_name     = data.terraform_remote_state.base.outputs.naver_client_id_secret_name
    naver_client_secret_secret_name = data.terraform_remote_state.base.outputs.naver_client_secret_secret_name
    alloy_config                    = local.alloy_config
    docker_compose_config           = local.docker_compose_config
  })

  tags = {
    Name = "quietchatter-frontend-node"
  }
}

output "frontend_private_ip" {
  value = aws_instance.frontend.private_ip
}
