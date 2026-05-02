data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "quietchatter-infra-assets"
    key    = "terraform/state/01-base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = data.terraform_remote_state.base.outputs.db_password_secret_name
}
