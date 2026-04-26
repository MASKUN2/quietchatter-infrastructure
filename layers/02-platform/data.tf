data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../01-base/terraform.tfstate"
  }
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.terraform_remote_state.base.outputs.db_password_secret_name
}
