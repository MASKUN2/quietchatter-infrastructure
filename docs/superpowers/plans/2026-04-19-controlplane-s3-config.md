# Controlplane S3 Config Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Terraform user_data에서 docker-compose.yaml과 config.alloy를 분리하여 S3 기반 동적 설정 관리 구조로 전환한다.

**Architecture:** S3에 설정 파일과 sync.sh 스크립트를 두고, EC2 인스턴스가 부팅 시 및 5분 주기로 S3에서 파일을 pull하여 변경 사항을 서비스 재시작 없이 반영한다. 시크릿은 Secrets Manager 태그 기반으로 자동 탐색한다.

**Tech Stack:** Terraform, AWS S3, AWS Secrets Manager, systemd, Bash, Grafana Alloy, Docker Compose

---

## 파일 변경 목록

Create:
- `layers/03-platform/s3.tf`
- `layers/03-platform/s3-assets/scripts/sync.sh`
- `layers/03-platform/s3-assets/config/docker-compose.yaml`
- `layers/03-platform/s3-assets/config/config.alloy`

Modify:
- `layers/01-base/secrets.tf` — controlplane 태그 추가
- `layers/01-base/iam.tf` — ListSecrets 권한 추가
- `layers/03-platform/controlplane.tf` — locals 제거, templatefile 인자 변경
- `layers/03-platform/variables.tf` — api_gateway_image 제거
- `layers/03-platform/templates/user_data.sh.tftpl` — 재작성

Delete:
- `layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl`

---

### Task 1: 01-base 시크릿에 controlplane 태그 추가

**Files:**
- Modify: `layers/01-base/secrets.tf`

- [ ] **Step 1: db_password와 grafana_api_key 시크릿에 태그 추가**

`layers/01-base/secrets.tf`의 `aws_secretsmanager_secret.db_password`와 `aws_secretsmanager_secret.grafana_api_key`에 tags 블록을 추가한다.

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name        = "quietchatter-db-password"
  description = "Database password for quietchatter microservices"

  recovery_window_in_days = 0

  tags = {
    controlplane = "true"
  }
}

resource "aws_secretsmanager_secret" "grafana_api_key" {
  name        = "quietchatter-grafana-api-key"
  description = "Grafana Cloud API Key for logs and metrics"

  recovery_window_in_days = 0

  tags = {
    controlplane = "true"
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd layers/01-base
git add secrets.tf
git commit -m "feat(infra): add controlplane tag to Secrets Manager secrets"
```

---

### Task 2: 01-base IAM 정책에 ListSecrets 권한 추가

**Files:**
- Modify: `layers/01-base/iam.tf`

sync.sh가 태그 기반으로 시크릿 목록을 조회하려면 `secretsmanager:ListSecrets` 권한이 필요하다. 이 액션은 리소스 수준 권한을 지원하지 않아 `*`를 사용한다.

- [ ] **Step 1: iam.tf에 ListSecrets statement 추가**

`layers/01-base/iam.tf`의 `aws_iam_role_policy.secrets_policy`를 아래와 같이 수정한다.

```hcl
resource "aws_iam_role_policy" "secrets_policy" {
  name = "quietchatter-secrets-policy"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.grafana_api_key.arn,
          aws_secretsmanager_secret.naver_client_id.arn,
          aws_secretsmanager_secret.naver_client_secret.arn,
          aws_secretsmanager_secret.jwt_secret_key.arn,
          aws_secretsmanager_secret.bff_jwt_secret_key.arn
        ]
      },
      {
        Action   = ["secretsmanager:ListSecrets"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

- [ ] **Step 2: terraform validate 실행**

```bash
cd layers/01-base
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: terraform plan 실행 — 변경 범위 확인**

```bash
terraform plan
```

Expected: `aws_iam_role_policy.secrets_policy` 교체 및 `aws_secretsmanager_secret` 2개 태그 추가만 포함. 인스턴스 교체 없음.

- [ ] **Step 4: Commit**

```bash
git add iam.tf
git commit -m "feat(infra): add ListSecrets IAM permission for tag-based secret discovery"
```

---

### Task 3: 03-platform S3 버킷 생성

**Files:**
- Create: `layers/03-platform/s3.tf`

- [ ] **Step 1: s3.tf 작성**

```hcl
resource "aws_s3_bucket" "controlplane_config" {
  bucket = "quietchatter-controlplane-config"

  tags = {
    Name = "quietchatter-controlplane-config"
  }
}

resource "aws_s3_bucket_public_access_block" "controlplane_config" {
  bucket = aws_s3_bucket.controlplane_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "controlplane_config_bucket" {
  value = aws_s3_bucket.controlplane_config.bucket
}
```

- [ ] **Step 2: 01-base/iam.tf에 S3 권한 statement 추가**

`aws_iam_role_policy.secrets_policy`의 Statement 배열에 아래를 추가한다.

```hcl
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.controlplane_config.arn,
          "${aws_s3_bucket.controlplane_config.arn}/*"
        ]
      }
```

S3 버킷 ARN을 참조하려면 `aws_s3_bucket.controlplane_config`가 03-platform에 있으므로, iam.tf에서 직접 참조할 수 없다. 대신 01-base/iam.tf에서 버킷 이름을 하드코딩한다.

```hcl
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::quietchatter-controlplane-config",
          "arn:aws:s3:::quietchatter-controlplane-config/*"
        ]
      }
```

- [ ] **Step 3: terraform validate 실행**

```bash
cd layers/03-platform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Commit**

```bash
git add s3.tf
cd ../01-base && git add iam.tf
git commit -m "feat(infra): add S3 bucket for controlplane config and IAM S3 permission"
```

---

### Task 4: sync.sh 작성

**Files:**
- Create: `layers/03-platform/s3-assets/scripts/sync.sh`

이 스크립트는 S3에 업로드되어 인스턴스에서 주기적으로 실행된다. `/etc/controlplane-config`에서 S3_BUCKET과 AWS_REGION을 읽는다.

시크릿 이름 → 환경변수 키 변환 규칙: `quietchatter-` 접두사 제거 후 소문자와 하이픈을 대문자와 언더스코어로 변환한다. 예) `quietchatter-db-password` → `DB_PASSWORD`

- [ ] **Step 1: s3-assets/scripts/ 디렉토리 생성 및 sync.sh 작성**

```bash
mkdir -p layers/03-platform/s3-assets/scripts
```

`layers/03-platform/s3-assets/scripts/sync.sh`:

```bash
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
```

- [ ] **Step 2: Commit**

```bash
git add layers/03-platform/s3-assets/scripts/sync.sh
git commit -m "feat(infra): add S3-based config sync script"
```

---

### Task 5: S3 에셋 설정 파일 준비

**Files:**
- Create: `layers/03-platform/s3-assets/config/docker-compose.yaml`
- Create: `layers/03-platform/s3-assets/config/config.alloy`

이 파일들은 Terraform 템플릿이 아닌 정적 파일이다. db_username, loki_url, loki_user 값을 01-base 출력에서 확인하여 직접 기재한다.

- [ ] **Step 1: 01-base 출력값 확인**

```bash
cd layers/01-base
terraform output db_username
terraform output grafana_cloud_logs_url
terraform output grafana_cloud_user
```

이 값들을 아래 파일에 직접 기재한다.

- [ ] **Step 2: docker-compose.yaml 작성**

`layers/03-platform/s3-assets/config/docker-compose.yaml`:

`<DB_USERNAME>` 자리에 위 Step 1에서 확인한 `db_username` 값을 넣는다.

```yaml
version: '3.8'
services:
  consul:
    image: hashicorp/consul:1.14
    container_name: quietchatter-consul
    restart: always
    volumes:
      - ./consul_data:/consul/data
      - ./consul_config:/consul/config
    environment:
      CONSUL_BIND_INTERFACE: ens5
      CONSUL_CLIENT_INTERFACE: ens5
    command: "agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -data-dir=/consul/data -config-dir=/consul/config"
    network_mode: host

  postgres:
    image: postgres:16-alpine
    container_name: quietchatter-postgres
    restart: always
    environment:
      POSTGRES_DB: quietchatter
      POSTGRES_USER: <DB_USERNAME>
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql:ro
    deploy:
      resources:
        limits:
          memory: 512M

  redis:
    image: redis:7-alpine
    container_name: quietchatter-redis
    restart: always
    ports:
      - "6379:6379"
    deploy:
      resources:
        limits:
          memory: 256M

  redpanda:
    image: docker.redpanda.com/redpandadata/redpanda:v23.2.1
    container_name: quietchatter-redpanda
    restart: always
    command:
      - redpanda start
      - --smp 1
      - --memory 768M
      - --reserve-memory 0M
      - --overprovisioned
      - --node-id 0
      - --check=false
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://localhost:9092,external://localhost:19092
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      - --advertise-schema-registry-addr internal://localhost:8081,external://localhost:18081
    ports:
      - "9092:9092"
      - "19092:19092"
      - "9644:9644"
      - "8081:8081"
      - "18081:18081"
    deploy:
      resources:
        limits:
          memory: 1G
```

- [ ] **Step 3: config.alloy 작성**

`layers/03-platform/s3-assets/config/config.alloy`:

`<LOKI_URL>`에 `grafana_cloud_logs_url` 값, `<LOKI_USER>`에 `grafana_cloud_user` 값을 넣는다.

```alloy
logging {
  level = "info"
}

loki.relabel "journal" {
  forward_to = [loki.write.grafana_cloud.receiver]

  rule {
    source_labels = ["__journal__systemd_unit"]
    target_label  = "unit"
  }
}

loki.source.journal "read" {
  forward_to    = [loki.relabel.journal.receiver]
  relabel_rules = loki.relabel.journal.rules
  labels        = {
    job          = "quietchatter/system",
    instance     = "quietchatter-controlplane-node",
    service_name = "system",
  }
}

discovery.docker "linux" {
  host = "unix:///var/run/docker.sock"
}

discovery.relabel "docker" {
  targets = discovery.docker.linux.targets

  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    replacement   = "$1"
    target_label  = "service_name"
  }

  rule {
    target_label = "instance"
    replacement  = "quietchatter-controlplane-node"
  }

  rule {
    target_label = "job"
    replacement  = "quietchatter/docker"
  }
}

loki.source.docker "logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.relabel.docker.output
  forward_to = [loki.write.grafana_cloud.receiver]
}

loki.write "grafana_cloud" {
  endpoint {
    url = "<LOKI_URL>"

    basic_auth {
      username = "<LOKI_USER>"
      password = sys.env("GRAFANA_API_KEY")
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add layers/03-platform/s3-assets/config/
git commit -m "feat(infra): add static S3 asset files for controlplane config"
```

---

### Task 6: user_data.sh.tftpl 재작성

**Files:**
- Modify: `layers/03-platform/templates/user_data.sh.tftpl`

기존 파일을 아래 내용으로 전체 교체한다. Terraform 변수는 `aws_region`, `s3_bucket_name`, `init_db_sql`만 남는다.

- [ ] **Step 1: user_data.sh.tftpl 전체 교체**

```bash
#!/bin/bash
set -e

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

error_handler() {
  log "ERROR: $1 단계에서 문제가 발생했습니다. 작업을 중단합니다."
  exit 1
}

log "INFO: userdata 스크립트 실행을 시작합니다."

# 0. 인터넷 연결 확인 (NAT 인스턴스 준비 대기)
log "STEP 0: 인터넷 연결을 확인하고 있습니다..."
until ping -c 1 8.8.8.8 > /dev/null 2>&1; do
  log "인터넷 연결 대기 중 (5초 후 재시도)..."
  sleep 5
done
log "인터넷 연결 확인 완료."

# 1. 시스템 설정 (Swap)
log "STEP 1: Swap 파일을 생성하고 시스템 설정을 진행합니다..."
{
  dd if=/dev/zero of=/swapfile bs=128M count=16
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
  fi
} || error_handler "Swap 설정"

# 2. EBS 볼륨 마운트 설정
log "STEP 2: EBS 볼륨(/dev/nvme1n1)을 확인하고 마운트합니다..."
{
  while [ ! -b /dev/nvme1n1 ]; do
    log "EBS 볼륨(/dev/nvme1n1) 대기 중..."
    sleep 2
  done

  if ! blkid /dev/nvme1n1; then
    log "새 볼륨에 파일 시스템(XFS) 생성 중..."
    mkfs -t xfs /dev/nvme1n1
  fi

  mkdir -p /data
  mount /dev/nvme1n1 /data

  if ! grep -q "/data" /etc/fstab; then
    echo "/dev/nvme1n1 /data xfs defaults,nofail 0 2" >> /etc/fstab
  fi
} || error_handler "EBS 볼륨 마운트"

# 3. Docker 설치
log "STEP 3: Docker 및 Docker Compose를 설치하고 있습니다..."
{
  dnf clean all
  dnf install docker -y || { log "Docker 설치 재시도 중..."; sleep 5; dnf install docker -y; }
  systemctl enable docker
  systemctl start docker
  mkdir -p /usr/local/lib/docker/cli-plugins/
  curl -SL https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-aarch64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
} || error_handler "Docker 설치"

# 4. Grafana Alloy 설치
log "STEP 4: Grafana Alloy를 설치합니다..."
{
  cat << 'REPO' > /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
REPO

  dnf install alloy -y
  usermod -aG docker alloy
  systemctl enable alloy
} || error_handler "Grafana Alloy 설치"

# 5. DB 초기화 스크립트 배치 (최초 1회)
log "STEP 5: DB 초기화 스크립트를 배치합니다..."
{
  mkdir -p /data/app
  cat <<'EOF' > /data/app/init-db.sql
${init_db_sql}
EOF
} || error_handler "DB 초기화 스크립트 배치"

# 6. 인프라 설정 파일 작성 (sync.sh가 읽는 설정)
log "STEP 6: 인프라 설정 파일을 작성합니다..."
{
  cat <<EOF > /etc/controlplane-config
AWS_REGION=${aws_region}
S3_BUCKET=${s3_bucket_name}
EOF
} || error_handler "인프라 설정 파일 작성"

# 7. S3에서 sync.sh 다운로드 및 초기 실행
log "STEP 7: S3에서 sync.sh를 다운로드하고 초기 설정을 실행합니다..."
{
  aws s3 cp "s3://${s3_bucket_name}/controlplane/scripts/sync.sh" \
    /usr/local/bin/sync.sh --region ${aws_region}
  chmod +x /usr/local/bin/sync.sh
  /usr/local/bin/sync.sh
} || error_handler "sync.sh 초기 실행"

# 8. systemd timer 등록
log "STEP 8: systemd timer를 등록합니다..."
{
  cat <<'EOF' > /etc/systemd/system/controlplane-config-sync.service
[Unit]
Description=Controlplane Config Sync
After=network.target docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync.sh
StandardOutput=journal
StandardError=journal
EOF

  cat <<'EOF' > /etc/systemd/system/controlplane-config-sync.timer
[Unit]
Description=Controlplane Config Sync Timer

[Timer]
OnBootSec=0
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now controlplane-config-sync.timer
} || error_handler "systemd timer 등록"

log "INFO: 모든 userdata 설정이 성공적으로 완료되었습니다."
```

- [ ] **Step 2: Commit**

```bash
git add layers/03-platform/templates/user_data.sh.tftpl
git commit -m "refactor(infra): rewrite user_data to bootstrap-only with S3 sync"
```

---

### Task 7: controlplane.tf locals 및 templatefile 인자 변경

**Files:**
- Modify: `layers/03-platform/controlplane.tf`

- [ ] **Step 1: locals 블록 제거 및 templatefile 인자 변경**

`layers/03-platform/controlplane.tf`에서 `locals` 블록 전체(alloy_config, docker_compose_config)를 삭제하고, `aws_instance.controlplane`의 `user_data` templatefile 인자를 변경한다.

파일 상단의 locals 블록 전체 삭제:

```hcl
# 삭제 대상 - locals 블록 전체 제거
locals {
  alloy_config = ...
  docker_compose_config = ...
}
```

`aws_instance.controlplane`의 user_data를 아래로 교체:

```hcl
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    s3_bucket_name = aws_s3_bucket.controlplane_config.bucket
    init_db_sql    = file("${path.module}/init-db.sql")
  })
```

- [ ] **Step 2: Commit**

```bash
git add layers/03-platform/controlplane.tf
git commit -m "refactor(infra): remove inline config locals, pass S3 bucket to user_data"
```

---

### Task 8: variables.tf 정리 및 tftpl 파일 삭제

**Files:**
- Modify: `layers/03-platform/variables.tf`
- Delete: `layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl`

- [ ] **Step 1: api_gateway_image 변수 제거**

`layers/03-platform/variables.tf`에서 아래 블록을 삭제한다.

```hcl
variable "api_gateway_image" {
  description = "Docker image for the API Gateway (Spring Cloud Gateway)"
  type        = string
  default     = "maskun2/quietchatter-microservice-api-gateway:latest"
}
```

- [ ] **Step 2: docker-compose.controlplane.yaml.tftpl 삭제**

```bash
git rm layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl
```

- [ ] **Step 3: Commit**

```bash
git add layers/03-platform/variables.tf
git commit -m "chore(infra): remove unused api_gateway_image var and docker-compose tftpl"
```

---

### Task 9: terraform validate 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: 01-base validate**

```bash
cd layers/01-base
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 2: 03-platform validate**

```bash
cd layers/03-platform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: 03-platform plan — 변경 범위 확인**

```bash
terraform plan
```

Expected:
- `aws_s3_bucket.controlplane_config` 추가
- `aws_s3_bucket_public_access_block.controlplane_config` 추가
- `aws_instance.controlplane` 교체 (user_data 변경으로 인한 마지막 1회 교체)
- `aws_volume_attachment.controlplane_att` 교체
- `aws_ebs_volume.controlplane_data` 변경 없음

---

### Task 10: 적용

- [ ] **Step 1: 01-base terraform apply**

```bash
cd layers/01-base
terraform apply
```

IAM 정책 업데이트와 시크릿 태그 추가만 발생. 인스턴스 영향 없음.

- [ ] **Step 2: S3 파일 업로드**

```bash
cd layers/03-platform

# 03-platform apply 전에 파일을 먼저 업로드해야 한다.
# S3 버킷이 없으므로 apply 후에 업로드한다 (Step 3 → Step 4 순서).
```

- [ ] **Step 3: 03-platform terraform apply (버킷 생성)**

```bash
cd layers/03-platform
terraform apply -target=aws_s3_bucket.controlplane_config \
  -target=aws_s3_bucket_public_access_block.controlplane_config
```

Expected: S3 버킷 2개 리소스만 생성.

- [ ] **Step 4: S3에 파일 업로드**

```bash
aws s3 cp s3-assets/scripts/sync.sh \
  s3://quietchatter-controlplane-config/controlplane/scripts/sync.sh

aws s3 cp s3-assets/config/docker-compose.yaml \
  s3://quietchatter-controlplane-config/controlplane/config/docker-compose.yaml

aws s3 cp s3-assets/config/config.alloy \
  s3://quietchatter-controlplane-config/controlplane/config/config.alloy
```

- [ ] **Step 5: 03-platform terraform apply (인스턴스 교체)**

```bash
terraform apply
```

인스턴스가 교체되고, 새 인스턴스가 부팅 시 sync.sh를 실행하여 서비스를 시작한다. EBS 데이터 볼륨은 유지된다.

- [ ] **Step 6: 동작 확인**

SSM Session Manager로 인스턴스에 접속하여 확인한다.

```bash
# 서비스 상태 확인
docker compose -f /data/app/docker-compose.yaml ps

# timer 상태 확인
systemctl status controlplane-config-sync.timer

# sync 로그 확인
journalctl -u controlplane-config-sync.service -n 50
```

Expected: consul, postgres, redis, redpanda 컨테이너 모두 running 상태.
