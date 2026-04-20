resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = aws_instance.gateway.id

  tags = {
    Name = "quietchatter-gateway-eip"
  }

  depends_on = [aws_instance.gateway]
}

resource "aws_instance" "gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  private_ip    = data.terraform_remote_state.base.outputs.gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/gateway_user_data.sh.tftpl", {
    aws_region      = var.aws_region
    s3_bucket_name  = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.api_gateway_image
    instance_name   = "quietchatter-gateway-node"
    loki_url        = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user       = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  tags = {
    Name = "quietchatter-gateway-node"
  }
}

output "gateway_public_ip" {
  value = aws_eip.gateway.public_ip
}

output "gateway_private_ip" {
  value = aws_instance.gateway.private_ip
}
