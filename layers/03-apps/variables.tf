variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-northeast-2"
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances (Amazon Linux 2023 ARM64)"
  type        = string
  default     = "ami-0e31683998cedb019"
}

variable "api_gateway_image" {
  description = "Docker image for the API Gateway (Spring Cloud Gateway)"
  type        = string
  default     = "maskun2/quietchatter-microservice-api-gateway:latest"
}

