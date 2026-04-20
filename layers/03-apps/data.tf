data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../01-base/terraform.tfstate"
  }
}

data "terraform_remote_state" "platform" {
  backend = "local"
  config = {
    path = "../02-platform/terraform.tfstate"
  }
}
