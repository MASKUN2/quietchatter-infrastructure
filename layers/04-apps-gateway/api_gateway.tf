resource "aws_instance" "api_gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.api_gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.api_gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                  = var.aws_region
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    alloy_config                = templatefile("${path.module}/templates/config.alloy.tftpl", {
                                     instance_name = "quietchatter-api-gateway-node"
                                     loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url                                    loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
                                  })
    docker_compose_config       = templatefile("${path.module}/templates/docker-compose.gateway.yaml.tftpl", {
                                    controlplane_ip = data.terraform_remote_state.base.outputs.controlplane_private_ip
                                    service_image   = var.api_gateway_image
                                  })
  })

  # Dependencies handled by user_data wait scripts across layers
  # depends_on = [
  #   aws_route.private_nat_route,
  #   aws_instance.controlplane
  # ]

  tags = {
    Name = "quietchatter-api-gateway-node"
  }
}

output "api_gateway_private_ip" {
  value = aws_instance.api_gateway.private_ip
}
