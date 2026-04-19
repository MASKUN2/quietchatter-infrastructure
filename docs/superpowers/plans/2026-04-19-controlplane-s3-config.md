# Controlplane S3 Config Separation Implementation Plan (Updated with Common Infra Assets)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Terraform user_data에서 docker-compose.yaml과 config.alloy를 분리하여 S3 기반 동적 설정 관리 구조로 전환한다. 특히 설정 파일 관리를 위해 01-base 레이어에 공통 인프라 에셋 버킷을 생성한다.

**Architecture:** 01-base 레이어에 생성된 `quietchatter-infra-assets` S3 버킷에 설정 파일과 sync.sh 스크립트를 두고, EC2 인스턴스(Controlplane, NAT)가 부팅 시 및 5분 주기로 S3에서 파일을 pull하여 변경 사항을 서비스 재시작 없이 반영한다. 시크릿은 Secrets Manager 태그 기반으로 자동 탐색한다.

**Tech Stack:** Terraform, AWS S3, AWS Secrets Manager, systemd, Bash, Grafana Alloy, Docker Compose, Nginx

---

## 파일 변경 목록

Create:
- `layers/01-base/s3.tf` — 공통 인프라 에셋 버킷 정의
- `layers/02-network-services/s3-assets/scripts/sync.sh`
- `layers/02-network-services/s3-assets/config/docker-compose.yaml`
- `layers/02-network-services/s3-assets/config/config.alloy`
- `layers/02-network-services/s3-assets/config/nginx.conf`
- `layers/03-platform/s3-assets/scripts/sync.sh`
- `layers/03-platform/s3-assets/config/docker-compose.yaml`
- `layers/03-platform/s3-assets/config/config.alloy`

Modify:
- `layers/01-base/secrets.tf` — controlplane 태그 추가
- `layers/01-base/iam.tf` — ListSecrets 및 S3 권한(리소스 참조 방식) 추가
- `layers/02-network-services/nat_ingress.tf` — 리팩토링된 user_data 적용
- `layers/02-network-services/templates/user_data.sh.tftpl` — 재작성
- `layers/03-platform/controlplane.tf` — locals 제거, S3 버킷 remote_state 참조로 변경
- `layers/03-platform/variables.tf` — api_gateway_image 제거
- `layers/03-platform/templates/user_data.sh.tftpl` — 재작성

Delete:
- `layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl`
- `layers/03-platform/templates/config.alloy.tftpl`

---

### Task 1: 01-base 시크릿 태그 및 공통 S3 버킷 생성

**Files:**
- Modify: `layers/01-base/secrets.tf`
- Create: `layers/01-base/s3.tf`

- [ ] **Step 1: db_password와 grafana_api_key 시크릿에 태그 추가**

`layers/01-base/secrets.tf`에 `controlplane = "true"` 태그를 추가한다.

- [ ] **Step 2: s3.tf 작성 (공통 인프라 에셋 버킷)**

```hcl
resource "aws_s3_bucket" "infra_assets" {
  bucket = "quietchatter-infra-assets"

  tags = {
    Name = "quietchatter-infra-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "infra_assets" {
  bucket = aws_s3_bucket.infra_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "infra_assets_bucket_name" {
  value = aws_s3_bucket.infra_assets.bucket
}
```

---

### Task 2: 01-base IAM 정책 업데이트

**Files:**
- Modify: `layers/01-base/iam.tf`

- [ ] **Step 1: iam.tf에 ListSecrets 및 S3 권한 추가**

하드코딩된 ARN 대신 `aws_s3_bucket.infra_assets.arn`을 참조하도록 수정한다.

```hcl
      {
        Action   = ["secretsmanager:ListSecrets"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.infra_assets.arn,
          "${aws_s3_bucket.infra_assets.arn}/*"
        ]
      }
```

---

### Task 3: sync.sh 및 설정 에셋 준비

**Files:**
- Create: `layers/03-platform/s3-assets/scripts/sync.sh`
- Create: `layers/03-platform/s3-assets/config/docker-compose.yaml`
- Create: `layers/03-platform/s3-assets/config/config.alloy`

- [ ] **Step 1: sync.sh 작성**
- [ ] **Step 2: 01-base 출력값을 확인하여 정적 설정 파일 작성**

---

### Task 4: user_data.sh.tftpl 및 controlplane.tf 리팩토링

**Files:**
- Modify: `layers/03-platform/templates/user_data.sh.tftpl`
- Modify: `layers/03-platform/controlplane.tf`

- [ ] **Step 1: user_data.sh.tftpl 재작성**
- [ ] **Step 2: controlplane.tf에서 locals 제거 및 S3 버킷 참조 업데이트**

```hcl
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    s3_bucket_name = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    init_db_sql    = file("${path.module}/init-db.sql")
  })
```

---

### Task 5: 적용 및 검증

- [ ] **Step 1: 01-base apply**
- [ ] **Step 2: S3 공통 버킷으로 에셋 업로드**
- [ ] **Step 3: 03-platform apply (인스턴스 교체)**
- [ ] **Step 4: SSM을 통한 동작 확인**
