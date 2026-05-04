---
name: s3-config-sync
description: Use when modifying sync.sh, updating k8s manifests in S3, or managing secrets injection on QuietChatter controlplane node
---

# S3 Config Sync Operations

## Overview

`sync.sh`는 controlplane 노드에서 5분 주기 systemd 타이머로 실행된다. S3에서 k8s 매니페스트를 내려받아 kubectl apply로 적용하고, AWS Secrets Manager 값을 k8s Secret으로 동기화한다.

## Quick Reference

| 상황 | 규칙 |
|---|---|
| 매니페스트 수정 | S3 업로드 후 최대 5분 대기 또는 sync.sh 수동 실행 |
| /home/ec2-user/ 하위 파일 생성 | 생성 직후 `chown ec2-user:ec2-user` 실행 |
| mktemp 사용 | 기본값 `/tmp/` 사용. `~` 지정 금지 (root 홈인 `/root/`로 해석됨) |
| sync.sh 경로 | `/home/ec2-user/sync.sh` |

## 매니페스트 수정 절차

S3 자산(sync.sh, manifests/)은 프로젝트 경로에 저장하지 않는다. 세션마다 임시경로를 사용한다.

```bash
# 1. 세션 임시경로 생성
TMP_DIR=$(mktemp -d)

# 2. S3에서 임시경로로 다운로드
aws s3 sync s3://quietchatter-infra-assets/controlplane/manifests/ "$TMP_DIR/manifests/" --region ap-northeast-2

# 3. 임시경로에서 수정

# 4. S3에 업로드
aws s3 cp "$TMP_DIR/manifests/<file>.yaml" s3://quietchatter-infra-assets/controlplane/manifests/<file>.yaml --region ap-northeast-2

# 5. 임시경로 정리 (선택)
rm -rf "$TMP_DIR"
```

매니페스트 구조 변경(strategy, env, probe 등)은 S3 직접 수정이 아닌 서비스 서브모듈 k8s/deployment.yaml을 수정하고 커밋한다. GitHub Actions가 이미지 치환 후 S3에 업로드한다.

## Secret 주입 패턴

sync.sh에서 Secrets Manager → k8s Secret 변환 (단일 JSON 시크릿 통합 방식):

```bash
SECRETS=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" --secret-id "quietchatter-secrets" \
  --query 'SecretString' --output text)

DB_PASSWORD=$(echo "$SECRETS" | jq -r '.db_password')
DB_USERNAME=$(echo "$SECRETS" | jq -r '.db_username')
GRAFANA_API_KEY=$(echo "$SECRETS" | jq -r '.grafana_api_key')
LOKI_URL=$(echo "$SECRETS" | jq -r '.loki_url')
LOKI_USER=$(echo "$SECRETS" | jq -r '.loki_user')
NAVER_CLIENT_ID=$(echo "$SECRETS" | jq -r '.naver_client_id')
NAVER_CLIENT_SECRET=$(echo "$SECRETS" | jq -r '.naver_client_secret')
JWT_SECRET_KEY=$(echo "$SECRETS" | jq -r '.jwt_secret_key')
INTERNAL_SECRET=$(echo "$SECRETS" | jq -r '.internal_secret')

kubectl create secret generic quietchatter-secrets \
  --namespace=quietchatter \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_USERNAME="$DB_USERNAME" \
  --from-literal=GRAFANA_API_KEY="$GRAFANA_API_KEY" \
  --from-literal=LOKI_URL="$LOKI_URL" \
  --from-literal=LOKI_USER="$LOKI_USER" \
  --from-literal=NAVER_CLIENT_ID="$NAVER_CLIENT_ID" \
  --from-literal=NAVER_CLIENT_SECRET="$NAVER_CLIENT_SECRET" \
  --from-literal=JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --from-literal=INTERNAL_SECRET="$INTERNAL_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -
```

`--dry-run=client -o yaml | kubectl apply -f -` 패턴을 사용하면 Secret이 이미 존재해도 오류 없이 업데이트된다.

현재 등록된 Secrets Manager 시크릿:
- `quietchatter-secrets`: 모든 애플리케이션 시크릿을 포함하는 단일 JSON 객체. `k3s_token`도 이 객체에 포함되어 있으며, EC2 user_data 스크립트가 jq로 파싱하여 노드 클러스터 참여에 사용한다. `k3s_token`은 k8s Secret으로는 변환하지 않는다.

## Common Mistakes

**Secrets Manager 조회 시 fallback 금지**
```bash
# Wrong: 조회 실패 시 빈 문자열로 폴백되어 앱이 기본값(예: "root")을 사용하게 됨
DB_USERNAME=$(aws secretsmanager ... --output text || echo "")

# Correct: 폴백 없이 실패 시 스크립트 중단 (set -e 환경에서 안전)
DB_USERNAME=$(aws secretsmanager ... --output text)
```

**파일 소유권 누락**
```bash
# Wrong: root 소유로 생성되어 이후 ec2-user 실행 시 Permission denied
cp /tmp/file /home/ec2-user/file

# Correct
cp /tmp/file /home/ec2-user/file
chown ec2-user:ec2-user /home/ec2-user/file
```

**mktemp 경로 오용**
```bash
# Wrong: root 실행 시 /root/tmp.XXXX 로 생성됨
TMP=$(mktemp ~/tmp.XXXX)

# Correct
TMP=$(mktemp)
```
