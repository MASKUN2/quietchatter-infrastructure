output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "nat_ingress_public_ip" {
  value       = aws_instance.nat_ingress.public_ip
  description = "Public IP of the NAT/NGINX Ingress instance"
}

output "api_gateway_private_ip" {
  value       = aws_instance.api_gateway.private_ip
  description = "Private IP of the API Gateway instance"
}

output "controlplane_private_ip" {
  value       = aws_instance.controlplane.private_ip
  description = "Private IP of the Control Plane instance"
}
