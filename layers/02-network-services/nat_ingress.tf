resource "aws_network_interface" "nat_ingress_eni" {
  subnet_id         = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  private_ips       = [data.terraform_remote_state.base.outputs.nat_private_ip]
  security_groups   = [data.terraform_remote_state.base.outputs.nat_ingress_sg_id]
  source_dest_check = false # Critical for NAT functionality

  tags = {
    Name = "quietchatter-nat-ingress-eni"
  }
}

resource "aws_instance" "nat_ingress" {
  ami           = var.ami_id
  instance_type = "t4g.nano"

  user_data_replace_on_change = true

  iam_instance_profile = data.terraform_remote_state.base.outputs.ssm_profile_name

  network_interface {
    network_interface_id = aws_network_interface.nat_ingress_eni.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region             = var.aws_region
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    vpc_cidr               = data.terraform_remote_state.base.outputs.vpc_cidr
    alloy_config           = templatefile("${path.module}/templates/config.alloy.tftpl", {
                               instance_name = "quietchatter-nat-ingress-node"
                               loki_url      = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
                               loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
                             })
    nginx_config           = templatefile("${path.module}/templates/nginx.conf.tftpl", {
                               frontend_ip = data.terraform_remote_state.base.outputs.frontend_private_ip
                             })
    docker_compose_config  = file("${path.module}/templates/docker-compose.nat-ingress.yaml")
  })

  tags = {
    Name = "quietchatter-nat-ingress-node"
  }
}

# Route internal traffic to the NAT Instance
resource "aws_route" "private_nat_route" {
  route_table_id         = data.terraform_remote_state.base.outputs.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.nat_ingress_eni.id
}
