variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-northeast-2"
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances (Amazon Linux 2023 ARM64)"
  type        = string
  default     = "ami-0e31683998cedb019"
}

variable "controlplane_private_ip" {
  description = "Static private IP for the Control Plane Node (Consul, DB, etc.)"
  type        = string
  default     = "10.0.101.100"
}
