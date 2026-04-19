resource "aws_instance" "ingress" {
  ami           = var.ami_id
  instance_type = "t4g.micro"

  user_data_replace_on_change = true

  subnet_id              = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.ingress_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name
  private_ip             = "10.0.1.50"

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    s3_bucket_name = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
  })

  tags = {
    Name = "quietchatter-ingress-node"
  }
}
