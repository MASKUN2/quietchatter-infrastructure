variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-northeast-2" # Example region (Seoul), change as needed
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances (Amazon Linux 2023 ARM64)"
  type        = string
  default     = "ami-0c2b29267104b2816" # Dummy AMI ID for validation in ap-northeast-2
}
