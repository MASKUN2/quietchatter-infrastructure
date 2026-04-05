# Database Password Secret
resource "aws_secretsmanager_secret" "db_password" {
  name        = "quietchatter-db-password"
  description = "Database password for quietchatter microservices"
  
  # Recovery window set to 0 for easy testing/destruction, change for production
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# Grafana Cloud API Key Secret
resource "aws_secretsmanager_secret" "grafana_api_key" {
  name        = "quietchatter-grafana-api-key"
  description = "Grafana Cloud API Key for logs and metrics"
  
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana_api_key" {
  secret_id     = aws_secretsmanager_secret.grafana_api_key.id
  secret_string = var.grafana_cloud_api_key
}
