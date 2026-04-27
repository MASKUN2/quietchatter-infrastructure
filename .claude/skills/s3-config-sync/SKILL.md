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

```bash
# 1. S3에서 로컬로 다운로드
aws s3 sync s3://quietchatter-infra-assets/controlplane/manifests/ ./.s3-assets/manifests/ --region ap-northeast-2

# 2. 로컬에서 수정

# 3. S3에 업로드
aws s3 cp ./.s3-assets/manifests/<file>.yaml s3://quietchatter-infra-assets/controlplane/manifests/<file>.yaml --region ap-northeast-2

# 4. .s3-assets/ 는 커밋에서 제외
```

## Secret 주입 패턴

sync.sh에서 Secrets Manager → k8s Secret 변환:

```bash
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id quietchatter-db-password --query 'SecretString' --output text)

kubectl create secret generic quietchatter-secrets \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --namespace=quietchatter \
  --dry-run=client -o yaml | kubectl apply -f -
```

`--dry-run=client -o yaml | kubectl apply -f -` 패턴을 사용하면 Secret이 이미 존재해도 오류 없이 업데이트된다.

## Common Mistakes

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
