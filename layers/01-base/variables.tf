variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-northeast-2"
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
  default     = "ami-0e31683998cedb019"
}

variable "nat_private_ip" {
  description = "Static private IP for the NAT Ingress Node"
  type        = string
  default     = "10.0.1.10"
}

variable "controlplane_private_ip" {
  description = "Static private IP for the Control Plane Node"
  type        = string
  default     = "10.0.101.100"
}

variable "gateway_private_ip" {
  description = "Static private IP for the Gateway Node (public subnet, 10.0.1.0/24)"
  type        = string
  default     = "10.0.1.100"
}

variable "db_password" {
  description = "Database password to store in Secrets Manager"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_cloud_api_key" {
  description = "Grafana Cloud API Key to store in Secrets Manager"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "grafana_cloud_user" {
  description = "Grafana Cloud User ID"
  type        = string
  default     = ""
}

variable "grafana_cloud_logs_url" {
  description = "Grafana Cloud Loki (Logs) URL"
  type        = string
  default     = ""
}

variable "naver_client_id" {
  description = "Naver OAuth Client ID for member and book microservices"
  type        = string
  sensitive   = true
  default     = ""
}

variable "naver_client_secret" {
  description = "Naver OAuth Client Secret for member and book microservices"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_secret_key" {
  description = "JWT signing secret key for member microservice"
  type        = string
  sensitive   = true
  default     = ""
}
