terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "quietchatter-infra-assets"
    key    = "terraform/state/01-base/terraform.tfstate"
    region = "ap-northeast-2"
    # DynamoDB table for locking is recommended but omitted if not created yet
    # dynamodb_table = "quietchatter-terraform-locks"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
