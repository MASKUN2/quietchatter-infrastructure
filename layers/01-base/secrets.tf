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

# Naver OAuth Client ID Secret (member and book microservices)
resource "aws_secretsmanager_secret" "naver_client_id" {
  name        = "quietchatter-naver-client-id"
  description = "Naver OAuth Client ID for member and book microservices"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "naver_client_id" {
  secret_id     = aws_secretsmanager_secret.naver_client_id.id
  secret_string = var.naver_client_id
}

# Naver OAuth Client Secret (member and book microservices)
resource "aws_secretsmanager_secret" "naver_client_secret" {
  name        = "quietchatter-naver-client-secret"
  description = "Naver OAuth Client Secret for member and book microservices"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "naver_client_secret" {
  secret_id     = aws_secretsmanager_secret.naver_client_secret.id
  secret_string = var.naver_client_secret
}

# JWT Secret Key (member microservice)
resource "aws_secretsmanager_secret" "jwt_secret_key" {
  name        = "quietchatter-jwt-secret-key"
  description = "JWT signing secret key for member microservice"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret_key" {
  secret_id     = aws_secretsmanager_secret.jwt_secret_key.id
  secret_string = var.jwt_secret_key
}

# k3s Cluster Token (shared by all k3s nodes)
resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "k3s_token" {
  name                    = "quietchatter-k3s-token"
  recovery_window_in_days = 0

  tags = {
    Name = "quietchatter-k3s-token"
  }
}

resource "aws_secretsmanager_secret_version" "k3s_token" {
  secret_id     = aws_secretsmanager_secret.k3s_token.id
  secret_string = random_password.k3s_token.result
}
