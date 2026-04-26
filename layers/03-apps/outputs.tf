output "gateway_public_ip" {
  value = aws_eip.gateway.public_ip
}

output "gateway_private_ip" {
  value = aws_instance.gateway.private_ip
}
