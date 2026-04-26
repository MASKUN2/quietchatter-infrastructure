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

variable "microservices" {
  description = "Map of microservices to deploy"
  type = map(object({
    port      = number
    image_var = string
  }))
  default = {
    book     = { port = 8081, image_var = "maskun2/quietchatter-microservice-book:latest" }
    customer = { port = 8082, image_var = "maskun2/quietchatter-microservice-customer:latest" }
    member   = { port = 8083, image_var = "maskun2/quietchatter-microservice-member:latest" }
    talk     = { port = 8084, image_var = "maskun2/quietchatter-microservice-talk:latest" }
  }
}
