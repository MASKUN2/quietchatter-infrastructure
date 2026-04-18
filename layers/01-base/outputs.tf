output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "nat_private_ip" {
  value = var.nat_private_ip
}

output "controlplane_private_ip" {
  value = var.controlplane_private_ip
}

output "api_gateway_private_ip" {
  value = var.api_gateway_private_ip
}

output "db_password_secret_name" {
  value = aws_secretsmanager_secret.db_password.name
}

output "grafana_api_key_secret_name" {
  value = aws_secretsmanager_secret.grafana_api_key.name
}

output "db_username" {
  value = var.db_username
}

output "grafana_cloud_user" {
  value = var.grafana_cloud_user
}

output "grafana_cloud_logs_url" {
  value = var.grafana_cloud_logs_url
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "nat_ingress_sg_id" {
  value = aws_security_group.nat_ingress.id
}

output "api_gateway_sg_id" {
  value = aws_security_group.api_gateway.id
}

output "microservices_sg_id" {
  value = aws_security_group.microservices.id
}

output "controlplane_sg_id" {
  value = aws_security_group.controlplane.id
}

output "ssm_profile_name" {
  value = aws_iam_instance_profile.ssm_profile.name
}

output "frontend_sg_id" {
  value = aws_security_group.frontend.id
}

output "frontend_private_ip" {
  value = var.frontend_private_ip
}

output "bff_jwt_secret_name" {
  value = aws_secretsmanager_secret.bff_jwt_secret_key.name
}

output "naver_client_id_secret_name" {
  value = aws_secretsmanager_secret.naver_client_id.name
}

output "naver_client_secret_secret_name" {
  value = aws_secretsmanager_secret.naver_client_secret.name
}
