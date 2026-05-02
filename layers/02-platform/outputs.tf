output "controlplane_private_ip" {
  value = aws_instance.controlplane.private_ip
}

output "rds_address" {
  value = aws_db_instance.main.address
}

output "rds_port" {
  value = aws_db_instance.main.port
}
