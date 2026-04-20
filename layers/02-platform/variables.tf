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

variable "controlplane_private_ip" {
  description = "Static private IP for the Control Plane Node (Consul, DB, etc.)"
  type        = string
  default     = "10.0.101.100"
}

variable "grafana_cloud_metrics_url" {
  description = "Grafana Cloud Prometheus (Metrics) URL"
  type        = string
  default     = ""
}

variable "microservices" {
  description = "Map of microservices to deploy via ASG"
  type = map(object({
    port        = number
    image_var   = string
  }))
  default = {
    book     = { port = 8081, image_var = "maskun2/quietchatter-microservice-book:latest" }
    customer = { port = 8082, image_var = "maskun2/quietchatter-microservice-customer:latest" }
    member   = { port = 8083, image_var = "maskun2/quietchatter-microservice-member:latest" }
    talk     = { port = 8084, image_var = "maskun2/quietchatter-microservice-talk:latest" }
  }
}

variable "kafka_brokers" {
  description = "Kafka broker addresses (e.g., controlplane_ip:9092)"
  type        = string
  default     = ""
}

variable "api_gateway_private_ip" {
  description = "Static private IP for the API Gateway Node"
  type        = string
  default     = "10.0.101.200"
}
