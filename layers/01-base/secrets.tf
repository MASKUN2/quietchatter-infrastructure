resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "quietchatter-secrets"
  description = "All application secrets for QuietChatter microservices"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    db_password         = var.db_password
    db_username         = var.db_username
    grafana_api_key     = var.grafana_cloud_api_key
    loki_url            = var.grafana_cloud_logs_url
    loki_user           = var.grafana_cloud_user
    naver_client_id     = var.naver_client_id
    naver_client_secret = var.naver_client_secret
    jwt_secret_key      = var.jwt_secret_key
    k3s_token           = var.k3s_token
    internal_secret     = var.internal_secret
  })
}
