terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "quietchatter-infra-assets"
    key    = "terraform/state/03-apps/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
