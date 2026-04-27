data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "quietchatter-infra-assets"
    key    = "terraform/state/01-base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "quietchatter-infra-assets"
    key    = "terraform/state/02-platform/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
