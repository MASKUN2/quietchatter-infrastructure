# Gateway EIP
resource "aws_eip" "gateway" {
  domain = "vpc"

  tags = {
    Name = "quietchatter-gateway-eip"
  }
}

resource "aws_eip_association" "gateway" {
  instance_id   = aws_instance.gateway.id
  allocation_id = aws_eip.gateway.id
}

# Gateway Node
resource "aws_instance" "gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  private_ip    = data.terraform_remote_state.base.outputs.gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/gateway_user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    k3s_server_ip    = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
    service_image    = var.api_gateway_image
    instance_name    = "quietchatter-gateway-node"
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  tags = {
    Name = "quietchatter-gateway-node"
  }
}

# Worker Node (replaces per-service ASGs)
resource "aws_instance" "worker" {
  ami           = var.ami_id
  instance_type = "t4g.small"
  subnet_id     = data.terraform_remote_state.base.outputs.private_subnet_ids[0]
  private_ip    = var.worker_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.microservices_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/worker_user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    k3s_server_ip    = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
    instance_name    = "quietchatter-worker-node"
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "quietchatter-worker-node"
  }
}
