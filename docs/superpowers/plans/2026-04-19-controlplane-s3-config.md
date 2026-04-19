# Controlplane & Network S3 Config Separation Implementation Plan (Final)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Terraform user_data에서 모든 복잡한 설정을 제거하고 S3 기반 동적 설정 관리 구조로 전환한다. 특히 NAT와 Ingress 역할을 분리하여 네트워크 가용성을 높이고, 모든 주요 노드(NAT, Ingress, Controlplane)가 공통 S3 에셋 버킷을 사용하도록 구성한다.

**Architecture:**
1. **Common S3 Bucket:** 01-base 레이어에 `quietchatter-infra-assets` 버킷 생성.
2. **NAT Node (01-base):** t4g.nano 사양으로 기초 레이어에 고정. 순수 IP Forwarding 및 Masquerading 역할 수행.
3. **Ingress Node (02-ingress):** t4g.micro 사양. Nginx와 Consul Client(DNS)를 실행하여 런타임 이름 풀이 지원.
4. **Controlplane Node (03-platform):** t4g.small 사양. 핵심 공유 서비스(Consul Server, DB, Kafka 등) 실행.
5. **Sync Mechanism:** 모든 노드는 부팅 시 및 5분 주기로 S3에서 sync.sh를 pull하여 설정(Docker Compose, Nginx, Alloy 등)을 서비스 재시작 없이 반영한다.

**Tech Stack:** Terraform, AWS S3, AWS Secrets Manager, systemd, Bash, Grafana Alloy, Docker Compose, Nginx, Consul DNS

---

## 파일 변경 목록

Create:
- `layers/01-base/s3.tf` — 공통 인프라 에셋 버킷 정의
- `layers/01-base/nat.tf` — 전용 NAT 인스턴스 및 라우팅 정의
- `layers/01-base/templates/nat_user_data.sh.tftpl` — NAT 부트스트랩 스크립트
- `layers/02-ingress/ingress.tf` — 단독 Ingress 인스턴스 정의
- `layers/02-ingress/s3-assets/scripts/sync.sh` — 범용 동기화 스크립트
- `layers/02-ingress/s3-assets/config/docker-compose.yaml` — Ingress & Consul Client 설정
- `layers/02-ingress/s3-assets/config/nginx.conf` — Consul DNS 기반 Nginx 설정
- `layers/03-platform/s3-assets/scripts/sync.sh` — 범용 동기화 스크립트 (공유)
- `layers/03-platform/s3-assets/config/docker-compose.yaml` — 플랫폼 서비스 설정
- `layers/03-platform/s3-assets/config/config.alloy` — 플랫폼 로깅 설정

Modify:
- `layers/01-base/security.tf` — nat-sg 및 ingress-sg 분리 정의
- `layers/01-base/variables.tf` — ami_id 등 필수 변수 추가
- `layers/01-base/outputs.tf` — 분리된 SG ID 및 NAT 정보 출력
- `layers/02-ingress/templates/user_data.sh.tftpl` — Ingress 전용으로 재작성
- `layers/03-platform/controlplane.tf` — locals 제거, S3 버킷 remote_state 참조로 변경
- `layers/03-platform/templates/user_data.sh.tftpl` — 경로 최적화 및 리팩토링

Delete:
- `layers/02-ingress/nat_ingress.tf` (ingress.tf로 대체)
- `layers/03-platform/templates/*.tftpl` (S3 정적 파일로 대체)

---

### Task 1: 기초 인프라 고도화 (01-base)

- [x] **Step 1: 공통 S3 버킷 생성** (`quietchatter-infra-assets`)
- [x] **Step 2: 보안 그룹 분리** (`nat-sg`, `ingress-sg`) 및 Consul DNS(8600) 포트 허용.
- [x] **Step 3: 전용 NAT 인스턴스 정의** (`nat.tf`, `t4g.nano`).
- [x] **Step 4: 프라이빗 라우팅 고정** (NAT 인스턴스를 기본 게이트웨이로 설정).

### Task 2: 네트워크 서비스 고도화 (02-ingress)

- [x] **Step 1: 단독 Ingress 인스턴스 구축** (`ingress.tf`, `t4g.micro`).
- [x] **Step 2: Consul DNS 연동** (docker-compose에 `consul-client` 추가).
- [x] **Step 3: Nginx 리팩토링** (Consul Resolver 및 런타임 변수 기반 proxy_pass 적용).

### Task 3: 플랫폼 서비스 전환 (03-platform)

- [x] **Step 1: Controlplane 인스턴스 S3 동기화 방식으로 전환.**
- [x] **Step 2: 기존 전용 S3 버킷 삭제 및 공통 버킷 참조 구조 확립.**

### Task 4: 동기화 및 검증

- [x] **Step 1: 범용 `sync.sh` 배포** (nginx.conf 동기화 로직 및 경로 접두사 지원).
- [x] **Step 2: 모든 노드(NAT, Ingress, CP) 상태 확인 및 동기화 로그 검증.**
