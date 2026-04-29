#!/bin/bash
set -euo pipefail

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

source /etc/infra-asset-config

export KUBECONFIG=/home/ec2-user/.kube/config

# 0. sync.sh 자기 자신 갱신
SELF=/home/ec2-user/sync.sh
TMP_SELF=$(mktemp)
aws s3 cp "s3://$S3_BUCKET/$S3_PATH_PREFIX/sync.sh" "$TMP_SELF" --region "$AWS_REGION"
if ! diff -q "$TMP_SELF" "$SELF" > /dev/null 2>&1; then
  cp "$TMP_SELF" "$SELF"
  chown ec2-user:ec2-user "$SELF"
  chmod +x "$SELF"
  rm "$TMP_SELF"
  log "INFO: sync.sh가 갱신되었습니다. 재실행합니다."
  exec "$SELF"
fi
rm "$TMP_SELF"

# 1. k3s API 준비 확인
log "STEP 1: k3s API 상태를 확인합니다..."
until kubectl get nodes > /dev/null 2>&1; do
  log "k3s API 준비 대기 중..."
  sleep 5
done

# 2. 노드 role 라벨 부여 (quietchatter.io/role → node-role.kubernetes.io/*)
log "STEP 2: 노드 role 라벨을 부여합니다..."
for role in controlplane platform gateway worker; do
  kubectl label node -l quietchatter.io/role=$role \
    node-role.kubernetes.io/$role=true --overwrite 2>/dev/null || true
done

# 3. k8s Secret 생성/갱신 (Secrets Manager → k8s Secret)
log "STEP 2: AWS Secrets Manager에서 시크릿을 동기화합니다..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-db-password" \
  --query 'SecretString' --output text)
DB_USERNAME=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-db-username" \
  --query 'SecretString' --output text)
GRAFANA_API_KEY=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-grafana-api-key" \
  --query 'SecretString' --output text)
LOKI_URL=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-loki-url" \
  --query 'SecretString' --output text)
LOKI_USER=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-loki-user" \
  --query 'SecretString' --output text)

kubectl create namespace quietchatter --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic quietchatter-secrets \
  --namespace=quietchatter \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_USERNAME="$DB_USERNAME" \
  --from-literal=GRAFANA_API_KEY="$GRAFANA_API_KEY" \
  --from-literal=LOKI_URL="$LOKI_URL" \
  --from-literal=LOKI_USER="$LOKI_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

log "INFO: 시크릿 동기화 완료."

# 4. S3에서 매니페스트 동기화 후 apply
log "STEP 3: S3에서 k8s 매니페스트를 동기화하고 적용합니다..."
MANIFEST_DIR=/home/ec2-user/manifests
mkdir -p "$MANIFEST_DIR"
aws s3 sync "s3://$S3_BUCKET/$S3_PATH_PREFIX/manifests/" "$MANIFEST_DIR/" \
  --region "$AWS_REGION" --delete

kubectl apply -f "$MANIFEST_DIR/" --recursive

log "INFO: 매니페스트 적용 완료."
log "INFO: 동기화 완료."
