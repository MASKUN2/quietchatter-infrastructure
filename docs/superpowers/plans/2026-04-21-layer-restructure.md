# Layer Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 6개 Terraform 레이어(01~06)를 3개(01-base, 02-platform, 03-apps)로 통합하고, 별도 Ingress 노드를 제거하여 NGINX를 Gateway 노드에 동거 배치한다.

**Architecture:** 01-base 보안 그룹을 리팩토링하여 ingress/api_gateway SG를 단일 gateway SG로 통합한다. 03-platform을 02-platform으로 이동하고, 04/05/06을 03-apps로 통합한다. Gateway 노드는 퍼블릭 서브넷 + EIP로 이동한다.

**Tech Stack:** Terraform >= 1.5.0, AWS provider ~> 5.0, local backend

---

## 파일 구조 변경 요약

생성:
- `layers/02-platform/` (03-platform 내용 그대로 이동)
- `layers/03-apps/providers.tf`
- `layers/03-apps/data.tf`
- `layers/03-apps/variables.tf`
- `layers/03-apps/gateway.tf`
- `layers/03-apps/microservices.tf`
- `layers/03-apps/frontend.tf`
- `layers/03-apps/templates/gateway_user_data.sh.tftpl`
- `layers/03-apps/templates/microservices_user_data.sh.tftpl`
- `layers/03-apps/templates/frontend_user_data.sh.tftpl`
- `layers/03-apps/templates/config.alloy.tftpl`
- `layers/03-apps/templates/docker-compose.frontend.yaml.tftpl`

수정:
- `layers/01-base/security.tf` (SG 리팩토링)
- `layers/01-base/outputs.tf` (output 이름 변경)
- `layers/01-base/variables.tf` (변수 이름 변경)

삭제:
- `layers/02-ingress/` (전체)
- `layers/03-platform/` (02-platform으로 이동 후)
- `layers/04-apps-gateway/` (03-apps로 통합 후)
- `layers/05-apps-microservices/` (03-apps로 통합 후)
- `layers/06-apps-frontend/` (03-apps로 통합 후)

---

### Task 1: 01-base 보안 그룹 리팩토링

**Files:**
- Modify: `layers/01-base/security.tf`
- Modify: `layers/01-base/outputs.tf`
- Modify: `layers/01-base/variables.tf`

- [ ] **Step 1: security.tf - ingress/api_gateway SG를 gateway SG로 통합**

`layers/01-base/security.tf`의 `aws_security_group.ingress`와 `aws_security_group.api_gateway` 블록을 제거하고, 아래 단일 `gateway` SG로 교체한다.

```hcl
resource "aws_security_group" "gateway" {
  name        = "quietchatter-gateway-sg"
  description = "Security group for Gateway node (NGINX + Spring Cloud Gateway)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quietchatter-gateway-sg"
  }
}
```

- [ ] **Step 2: security.tf - frontend/microservices/controlplane SG의 참조 업데이트**

`aws_security_group.frontend` 안의 ingress 규칙에서 `aws_security_group.ingress.id`를 `aws_security_group.gateway.id`로 변경한다.

```hcl
resource "aws_security_group" "frontend" {
  # ... 기존 내용 유지 ...
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.gateway.id]
  }
  # Consul serf 규칙은 그대로 유지
}
```

`aws_security_group.microservices` 안의 `aws_security_group.api_gateway.id`를 `aws_security_group.gateway.id`로 변경한다.

```hcl
resource "aws_security_group" "microservices" {
  # ... 기존 내용 유지 ...
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    security_groups = [
      aws_security_group.gateway.id
    ]
  }
}
```

`aws_security_group.controlplane` 안의 모든 `aws_security_group.api_gateway.id` 참조를 `aws_security_group.gateway.id`로 변경한다. (PostgreSQL, Redis, Kafka, Redpanda 각 ingress 블록)

- [ ] **Step 3: outputs.tf - SG 출력 업데이트**

`layers/01-base/outputs.tf`에서 아래 두 output을 제거한다.

```hcl
# 제거
output "ingress_sg_id" { ... }
output "api_gateway_sg_id" { ... }
output "api_gateway_private_ip" { ... }
```

아래 output을 추가한다.

```hcl
output "gateway_sg_id" {
  value = aws_security_group.gateway.id
}

output "gateway_private_ip" {
  value = var.gateway_private_ip
}
```

- [ ] **Step 4: variables.tf - api_gateway_private_ip를 gateway_private_ip로 변경**

`layers/01-base/variables.tf`에서 `api_gateway_private_ip` 변수를 찾아 아래로 교체한다.

```hcl
variable "gateway_private_ip" {
  description = "Static private IP for the Gateway Node (public subnet, 10.0.1.0/24)"
  type        = string
  default     = "10.0.1.100"
}
```

- [ ] **Step 5: terraform validate 실행**

```bash
cd layers/01-base
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
git add layers/01-base/security.tf layers/01-base/outputs.tf layers/01-base/variables.tf
git commit -m "refactor(infra): consolidate ingress/gateway security groups into single gateway-sg"
```

---

### Task 2: 02-platform 레이어 생성

**Files:**
- Create: `layers/02-platform/` (03-platform 전체 복사)

- [ ] **Step 1: 디렉토리 복사**

```bash
cp -r layers/03-platform layers/02-platform
```

- [ ] **Step 2: terraform.tfstate 파일 제거 (새 레이어로 별도 init)**

```bash
rm -f layers/02-platform/terraform.tfstate
rm -f layers/02-platform/terraform.tfstate.backup
rm -f layers/02-platform/terraform.tfstate.*.backup
```

- [ ] **Step 3: terraform init 및 validate 실행**

```bash
cd layers/02-platform
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Commit**

```bash
git add layers/02-platform/
git commit -m "refactor(infra): add 02-platform layer (moved from 03-platform)"
```

---

### Task 3: 03-apps 레이어 생성 - 기반 파일

**Files:**
- Create: `layers/03-apps/providers.tf`
- Create: `layers/03-apps/data.tf`
- Create: `layers/03-apps/variables.tf`

- [ ] **Step 1: providers.tf 작성**

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

파일 저장 위치: `layers/03-apps/providers.tf`

- [ ] **Step 2: data.tf 작성**

```hcl
data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../01-base/terraform.tfstate"
  }
}

data "terraform_remote_state" "platform" {
  backend = "local"
  config = {
    path = "../02-platform/terraform.tfstate"
  }
}
```

파일 저장 위치: `layers/03-apps/data.tf`

- [ ] **Step 3: variables.tf 작성**

```hcl
variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-northeast-2"
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances (Amazon Linux 2023 ARM64)"
  type        = string
  default     = "ami-0e31683998cedb019"
}

variable "api_gateway_image" {
  description = "Docker image for the API Gateway (Spring Cloud Gateway)"
  type        = string
  default     = "maskun2/quietchatter-microservice-api-gateway:latest"
}

variable "frontend_image" {
  description = "Docker image for the Next.js BFF"
  type        = string
  default     = "maskun2/quietchatter-frontend:latest"
}

variable "microservices" {
  description = "Map of microservices to deploy"
  type = map(object({
    port      = number
    image_var = string
  }))
  default = {
    book     = { port = 8081, image_var = "maskun2/quietchatter-microservice-book:latest" }
    customer = { port = 8082, image_var = "maskun2/quietchatter-microservice-customer:latest" }
    member   = { port = 8083, image_var = "maskun2/quietchatter-microservice-member:latest" }
    talk     = { port = 8084, image_var = "maskun2/quietchatter-microservice-talk:latest" }
  }
}
```

파일 저장 위치: `layers/03-apps/variables.tf`

---

### Task 4: 03-apps/gateway.tf 작성

**Files:**
- Create: `layers/03-apps/gateway.tf`
- Create: `layers/03-apps/templates/gateway_user_data.sh.tftpl`

- [ ] **Step 1: gateway.tf 작성**

기존 04-apps-gateway/api_gateway.tf를 기반으로 하되, 퍼블릭 서브넷 배치 및 EIP 추가.

```hcl
resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = aws_instance.gateway.id

  tags = {
    Name = "quietchatter-gateway-eip"
  }

  depends_on = [aws_instance.gateway]
}

resource "aws_instance" "gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  private_ip    = data.terraform_remote_state.base.outputs.gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/gateway_user_data.sh.tftpl", {
    aws_region      = var.aws_region
    s3_bucket_name  = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.api_gateway_image
    instance_name   = "quietchatter-gateway-node"
    loki_url        = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user       = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  tags = {
    Name = "quietchatter-gateway-node"
  }
}

output "gateway_public_ip" {
  value = aws_eip.gateway.public_ip
}

output "gateway_private_ip" {
  value = aws_instance.gateway.private_ip
}
```

파일 저장 위치: `layers/03-apps/gateway.tf`

- [ ] **Step 2: gateway_user_data.sh.tftpl 작성**

`layers/04-apps-gateway/templates/user_data.sh.tftpl` 내용을 그대로 복사하여 저장한다.

```bash
cp layers/04-apps-gateway/templates/user_data.sh.tftpl \
   layers/03-apps/templates/gateway_user_data.sh.tftpl
```

---

### Task 5: 03-apps/microservices.tf 작성

**Files:**
- Create: `layers/03-apps/microservices.tf`
- Create: `layers/03-apps/templates/microservices_user_data.sh.tftpl`

- [ ] **Step 1: microservices.tf 작성**

`layers/05-apps-microservices/microservices.tf` 내용을 그대로 복사한다. data.tf에서 이미 platform 경로를 `../02-platform`으로 정의했으므로 내용 변경 없음.

```bash
cp layers/05-apps-microservices/microservices.tf layers/03-apps/microservices.tf
```

- [ ] **Step 2: microservices user_data 템플릿 복사**

```bash
cp layers/05-apps-microservices/templates/user_data.sh.tftpl \
   layers/03-apps/templates/microservices_user_data.sh.tftpl
```

- [ ] **Step 3: microservices.tf의 템플릿 경로 수정**

`layers/03-apps/microservices.tf`에서 templatefile 경로를 변경한다.

변경 전:
```hcl
user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
```

변경 후:
```hcl
user_data = base64encode(templatefile("${path.module}/templates/microservices_user_data.sh.tftpl", {
```

---

### Task 6: 03-apps/frontend.tf 작성

**Files:**
- Create: `layers/03-apps/frontend.tf`
- Create: `layers/03-apps/templates/frontend_user_data.sh.tftpl`
- Create: `layers/03-apps/templates/config.alloy.tftpl`
- Create: `layers/03-apps/templates/docker-compose.frontend.yaml.tftpl`

- [ ] **Step 1: frontend.tf 작성**

`layers/06-apps-frontend/frontend.tf` 내용을 그대로 복사한다.

```bash
cp layers/06-apps-frontend/frontend.tf layers/03-apps/frontend.tf
```

- [ ] **Step 2: frontend 템플릿 파일 복사**

```bash
cp layers/06-apps-frontend/templates/user_data.sh.tftpl \
   layers/03-apps/templates/frontend_user_data.sh.tftpl
cp layers/06-apps-frontend/templates/config.alloy.tftpl \
   layers/03-apps/templates/config.alloy.tftpl
cp layers/06-apps-frontend/templates/docker-compose.frontend.yaml.tftpl \
   layers/03-apps/templates/docker-compose.frontend.yaml.tftpl
```

- [ ] **Step 3: frontend.tf의 템플릿 경로 수정**

`layers/03-apps/frontend.tf`에서 user_data.sh.tftpl 참조를 변경한다.

변경 전:
```hcl
user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
```

변경 후:
```hcl
user_data = templatefile("${path.module}/templates/frontend_user_data.sh.tftpl", {
```

config.alloy.tftpl과 docker-compose.frontend.yaml.tftpl의 경로는 `${path.module}/templates/...`이므로 변경 불필요.

- [ ] **Step 4: terraform init 및 validate 실행**

```bash
cd layers/03-apps
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Commit**

```bash
git add layers/03-apps/
git commit -m "refactor(infra): add 03-apps layer (merged from 04-gateway, 05-microservices, 06-frontend)"
```

---

### Task 7: 배포 - 기존 레이어 제거 및 신규 레이어 적용

> 주의: 이 태스크는 실제 인프라를 변경한다. 단계별로 진행하고 각 단계 완료 후 상태를 확인한다.

- [ ] **Step 1: 기존 앱 레이어 destroy (역순)**

```bash
cd layers/06-apps-frontend && terraform destroy -auto-approve
cd ../05-apps-microservices && terraform destroy -auto-approve
cd ../04-apps-gateway && terraform destroy -auto-approve
cd ../02-ingress && terraform destroy -auto-approve
```

- [ ] **Step 2: 01-base apply**

Step 1에서 앱 레이어 인스턴스를 destroy했으므로 ingress_sg, api_gateway_sg는 사용 중인 리소스가 없다. 그대로 apply하면 된다.

```bash
cd layers/01-base
terraform plan
terraform apply
```

Expected: ingress_sg 삭제, api_gateway_sg 삭제, gateway_sg 생성, frontend/microservices/controlplane SG 규칙 업데이트.

- [ ] **Step 3: 02-platform state 복사 (Controlplane 노드 유지)**

03-platform을 destroy하지 않는다. Controlplane 인스턴스는 유지하면서 state 파일만 02-platform으로 복사한다.

```bash
cp layers/03-platform/terraform.tfstate layers/02-platform/terraform.tfstate
```

- [ ] **Step 4: 02-platform plan으로 상태 검증**

```bash
cd layers/02-platform
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.` (state를 복사했으므로 변경 없음)

- [ ] **Step 6: 03-apps apply**

```bash
cd layers/03-apps
terraform apply
```

Expected: Gateway 인스턴스(퍼블릭 서브넷, EIP), Microservices ASG, Frontend 인스턴스 생성.

- [ ] **Step 7: 검증**

```bash
# Gateway EIP 확인
cd layers/03-apps
terraform output gateway_public_ip

# 보안 그룹 확인 (AWS CLI)
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=quietchatter-gateway-sg" \
  --query 'SecurityGroups[0].IpPermissions' \
  --region ap-northeast-2
```

Expected: gateway_public_ip가 출력되고, 보안 그룹에 80/443 인바운드 규칙이 있음.

- [ ] **Step 8: 구 레이어 디렉토리 삭제**

```bash
rm -rf layers/02-ingress
rm -rf layers/03-platform
rm -rf layers/04-apps-gateway
rm -rf layers/05-apps-microservices
rm -rf layers/06-apps-frontend
```

- [ ] **Step 9: 최종 Commit**

```bash
git add -A
git commit -m "refactor(infra): complete layer restructure from 6 layers to 3 layers, remove ingress node"
```

---

## 배포 전 검증 결과 (2026-04-21)

코드 변경 완료 후 전 레이어에 대해 terraform validate 및 plan을 실행한 결과이다.

| 레이어 | tfstate | validate | plan 결과 |
|--------|---------|----------|-----------|
| 01-base | 있음 | PASS | 1 추가, 3 변경, 2 삭제 (gateway_sg 생성, ingress_sg/api_gateway_sg 삭제) |
| 02-ingress (삭제 예정) | 있음 | PASS | 미실행 |
| 02-platform (신규) | 없음 | PASS | 3 추가 (controlplane 관련 리소스) |
| 03-platform (삭제 예정) | 있음 | PASS | 미실행 |
| 03-apps (신규) | 없음 | PASS | 02-platform state 없어 부분 오류 (예상된 상태) |
| 04-apps-gateway (삭제 예정) | 있음 | PASS | 미실행 |
| 05-apps-microservices (삭제 예정) | 있음 | PASS (경고 1개) | 미실행 |
| 06-apps-frontend (삭제 예정) | 없음 | PASS | 미실행 |

배포 순서 및 블로커:
- 모든 레이어 validate 통과, 오류 없음
- 01-base apply → 02-platform apply → 03-apps apply 순서로 진행해야 함
- 03-apps는 02-platform tfstate 생성 전까지 plan/apply 불가 (예상된 의존성)
- 06-apps-frontend는 tfstate가 없으므로 destroy 없이 디렉토리만 삭제

## 스펙 커버리지 검증

| 스펙 요구사항 | 구현 태스크 |
|---|---|
| 02-ingress 레이어 삭제 | Task 7 Step 1, 8 |
| 03-platform → 02-platform 이동 | Task 2, Task 7 Step 4-5 |
| 04+05+06 → 03-apps 통합 | Task 3-6 |
| Gateway 퍼블릭 서브넷 + EIP | Task 4 |
| NGINX 동거 (S3 sync으로 관리) | gateway_user_data S3_PATH_PREFIX=gateway (기존 유지) |
| 보안 그룹 gateway_sg 단일화 | Task 1 |
| remote_state 경로 02-platform 참조 | Task 3 Step 2 |
