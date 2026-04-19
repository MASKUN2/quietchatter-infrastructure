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
    aws_region     = var.aws_region
    s3_bucket_name = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    vpc_cidr       = data.terraform_remote_state.base.outputs.vpc_cidr
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
