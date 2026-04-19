#!/bin/bash
set -euo pipefail

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

source /etc/controlplane-config

COMPOSE_CHANGED=false
ALLOY_CHANGED=false
SECRETS_CHANGED=false

# 1. 시크릿 동기화 (tag: controlplane=true)
log "INFO: Secrets Manager에서 시크릿을 동기화합니다..."

SECRET_ARNS=$(aws secretsmanager list-secrets \
  --region "$AWS_REGION" \
  --filters Key=tag-key,Values=controlplane \
  --query 'SecretList[].ARN' \
  --output text)

TMP_ENV=$(mktemp)
for ARN in $SECRET_ARNS; do
  NAME=$(aws secretsmanager describe-secret \
    --region "$AWS_REGION" \
    --secret-id "$ARN" \
    --query 'Name' \
    --output text)
  VALUE=$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$ARN" \
    --query 'SecretString' \
    --output text)
  ENV_KEY=$(echo "$NAME" | sed 's/^quietchatter-//' | tr '[:lower:]-' '[:upper:]_')
  echo "$ENV_KEY=$VALUE" >> "$TMP_ENV"
done

if [ ! -f /data/app/.env ] || ! diff -q "$TMP_ENV" /data/app/.env > /dev/null 2>&1; then
  cp "$TMP_ENV" /data/app/.env
  chmod 600 /data/app/.env
  cp "$TMP_ENV" /etc/sysconfig/alloy
  SECRETS_CHANGED=true
  log "INFO: 시크릿이 변경되었습니다."
fi
rm "$TMP_ENV"

# 2. docker-compose.yaml 동기화
log "INFO: docker-compose.yaml을 S3에서 동기화합니다..."
aws s3 cp "s3://$S3_BUCKET/controlplane/config/docker-compose.yaml" \
  /tmp/docker-compose.yaml.new --region "$AWS_REGION"

if [ ! -f /data/app/docker-compose.yaml ] || \
   ! diff -q /tmp/docker-compose.yaml.new /data/app/docker-compose.yaml > /dev/null 2>&1; then
  cp /tmp/docker-compose.yaml.new /data/app/docker-compose.yaml
  COMPOSE_CHANGED=true
  log "INFO: docker-compose.yaml이 변경되었습니다."
fi

# 3. config.alloy 동기화
log "INFO: config.alloy를 S3에서 동기화합니다..."
aws s3 cp "s3://$S3_BUCKET/controlplane/config/config.alloy" \
  /tmp/config.alloy.new --region "$AWS_REGION"

if [ ! -f /etc/alloy/config.alloy ] || \
   ! diff -q /tmp/config.alloy.new /etc/alloy/config.alloy > /dev/null 2>&1; then
  cp /tmp/config.alloy.new /etc/alloy/config.alloy
  ALLOY_CHANGED=true
  log "INFO: config.alloy가 변경되었습니다."
fi

# 4. 변경 반영
if [ "$COMPOSE_CHANGED" = true ] || [ "$SECRETS_CHANGED" = true ]; then
  log "INFO: Docker Compose 서비스를 재시작합니다..."
  cd /data/app && docker compose up -d
fi

if [ "$ALLOY_CHANGED" = true ] || [ "$SECRETS_CHANGED" = true ]; then
  log "INFO: Alloy를 재시작합니다..."
  systemctl restart alloy
fi

log "INFO: 동기화 완료."
