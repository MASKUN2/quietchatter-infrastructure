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

output "gateway_private_ip" {
  value = var.gateway_private_ip
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

output "nat_sg_id" {
  value = aws_security_group.nat.id
}

output "gateway_sg_id" {
  value = aws_security_group.gateway.id
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

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "nat_instance_id" {
  value = aws_instance.nat.id
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}

output "infra_assets_bucket_name" {
  value = aws_s3_bucket.infra_assets.bucket
}

output "infra_assets_bucket_arn" {
  value = aws_s3_bucket.infra_assets.arn
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

# Consolidated secret - used by all layers that need to fetch secrets
output "app_secret_name" {
  value = aws_secretsmanager_secret.app_secrets.name
}

# Kept for compatibility with 02-platform and 03-apps user_data templates
output "k3s_token_secret_name" {
  value = aws_secretsmanager_secret.app_secrets.name
}

# Kept for compatibility with 02-platform/data.tf (RDS password)
output "db_password_secret_name" {
  value = aws_secretsmanager_secret.app_secrets.name
}
