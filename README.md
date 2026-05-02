---
description: QuietChatter 인프라 구축 전략, 배포 가이드, 현재 상태 및 주요 의사결정 이력을 통합한 단일 문서
user-review:
instructions: |-
  -섹션구조 레벨을 #, ## 까지만 허용
  - "# 2. 히스토리 및 의사결정 요약" 은 매 작업마다 압축하십시오.
  - frontmatter "user-review" 에 대한 작업이 완료된 경우, 리뷰 내용만 지움.
---


# 1. 아키텍처 개요

## 목적 및 전략

본 인프라는 AWS 환경에서 최소한의 비용으로 마이크로서비스를 k3s 클러스터로 운영하기 위한 구조를 채택합니다.

- 단일 k3s 클러스터: Controlplane(서버) + Gateway(에이전트) + Worker ASG(에이전트) 3노드 구성
- 서비스 디스커버리: k3s 내장 CoreDNS, 서비스 이름 기반 DNS(service.namespace.svc.cluster.local)
- 안정성 강화: 모든 노드에 2GB 스왑 메모리 설정으로 OOM 방어
- 보안 강화: 22번 포트 차단 및 AWS SSM Session Manager를 통한 무키 접속 환경 구축

## 레이어 구성

- 01-base
	- NAT 노드: 프라이빗 서브넷 인터넷 아웃바운드 라우팅, iptables VPC CIDR 마스커레이딩
	- 공통 기반: 전체 레이어 보안 그룹, IAM/SSM 프로파일, Secrets Manager 시크릿(단일 JSON), S3 자산 버킷 관리
	- 시크릿 관리: 모든 애플리케이션 시크릿을 단일 JSON 시크릿(quietchatter-secrets)으로 통합 관리. sync.sh가 jq로 파싱하여 k8s Secret 오브젝트로 변환

- 02-platform
	- Controlplane 노드(t4g.small): k3s server, Redis StatefulSet, Redpanda StatefulSet 구동
	- RDS PostgreSQL: AWS 관리형 db.t4g.micro, 프라이빗 서브넷 배치

- 03-apps
	- Gateway 노드(t4g.micro, 퍼블릭): k3s agent, EIP 고정. NGINX(HostNetwork) + Spring Cloud Gateway Pod
	- Worker ASG(t4g.small, Spot-only, min=1/max=3): k3s agent. 3개 마이크로서비스 Pod 실행(member, book, talk). CPU 70% 초과 시 자동 스케일아웃

## 워크로드 배포 방식

매니페스트는 S3(s3://quietchatter-infra-assets/controlplane/manifests/)에서 관리된다.
Controlplane의 systemd timer(5분 주기)가 sync.sh를 실행하여 kubectl apply로 변경을 반영한다.

매니페스트의 구조적 원본은 각 서비스 서브모듈의 k8s/deployment.yaml(IMAGE_PLACEHOLDER 포함 템플릿)이다. GitHub Actions가 이미지 빌드 후 SHA로 치환하여 S3에 업로드한다.

매니페스트 구조 변경 시 지켜야 할 규칙:
- 서비스 서브모듈 k8s/deployment.yaml을 수정하고 커밋한다. GitHub Actions가 S3를 업데이트한다.
- S3를 직접 수정한 경우(긴급 패치 등), 반드시 서비스 서브모듈 k8s/deployment.yaml에도 반영하고 커밋한다. 그렇지 않으면 다음 GitHub Actions 실행 시 변경이 롤백된다.
- sync.sh를 수정한 경우, S3에 직접 업로드한다. 로컬 복사본을 프로젝트에 두지 않는다.

## 예상 비용

- 서울 리전 기준 월 총합 약 10.80 달러 (3노드: controlplane t4g.small + gateway t4g.micro + worker t4g.small Spot)

---

# 2. 히스토리 및 의사결정 요약

## 예정 작업

- [나중에]고가용성: 다중 AZ 배포
- 데이터 보호: EBS 일일 스냅샷, PostgreSQL 덤프 S3 보관
- 프로비저닝 최적화: Packer Custom AMI, S3 검증 바이너리
- 보안: Let's Encrypt/ACM HTTPS 적용, 노드별 IAM Role 세분화
- 관찰성: Node Exporter/Prometheus 메트릭 수집, 임계치 알람 구성
- 운영: AWS Node Termination Handler 도입으로 Spot 종료 시 k3s 노드 자동 제거

## 비표준 구현 및 표준 대안

현재 구현이 업계 표준과 다른 부분과 그 대안을 기록한다.

워크로드 배포(sync.sh S3 폴링):
- 현재: controlplane systemd 타이머가 5분마다 S3에서 매니페스트를 받아 kubectl apply
- 표준: ArgoCD 또는 Flux (GitOps). Git 저장소를 직접 감시하다 변경 즉시 반영. 배포 이력 추적 및 롤백 UI 제공
- 채택 이유: 포트폴리오 규모에서 ArgoCD 운영 비용(메모리, 복잡도) 대비 효용이 낮아 단순화

시크릿 주입(sync.sh 수동 변환):
- 현재: sync.sh가 AWS Secrets Manager의 단일 JSON 시크릿(quietchatter-secrets)을 jq로 파싱해 kubectl create secret으로 k8s Secret을 직접 생성. 파드는 deployment.yaml의 secretKeyRef로 env var 주입
- 표준: External Secrets Operator(ESO). k8s CRD로 선언하면 ESO가 Secrets Manager를 감시하며 자동 동기화
- 채택 이유: ESO 설치 및 CRD 관리 복잡도 대비 소규모 운영에서는 수동으로 충분

## 과거 의사결정

- S3 동기화 구조 전환 (2026-04-19): user_data 방식 → systemd 타이머 + sync.sh + S3 버킷(quietchatter-infra-assets). 인프라 교체 없이 설정 즉시 반영
- 비밀 관리 강화: 평문 환경변수 → AWS Secrets Manager 런타임 조회. 태그 기반 자동 조회
- Grafana Alloy 로깅 안정화: alloy 계정에 docker 그룹 추가, discovery.relabel로 service_name 라벨링 정상화
- Consul 안정화: 1.15 → 1.14 다운그레이드, 컨테이너 네트워크 모드 host로 변경
- Frontend 노드 제거 (2026-04-26): Next.js BFF 인프라 자원 및 설정 전면 삭제
- 레이어 6→3 통합 (2026-04-21): 02-ingress 제거, 04~06-apps → 03-apps. remote_state 단순화 및 비용 절감
- 프로비저닝 안정화: dnf 캐시 충돌 해결, 재시도 로직 및 set -e 적용
- k3s 전환 (2026-04-26): Consul + Docker Compose 기반 → k3s 단일 클러스터 전환. 서비스 디스커버리를 CoreDNS로 교체, 4개 마이크로서비스 ASG를 단일 Worker EC2로 통합, 비용 절감 및 포트폴리오 k8s 경험 확보
- 노드 구조 개편 (2026-04-27): Redpanda를 Controlplane에서 분리해 전용 Platform 노드(t4g.micro)로 이동. Controlplane을 t4g.small → t4g.micro로 다운그레이드. Worker EC2를 Spot-only ASG(min=1/max=3)로 전환. 월 비용 ~$20 → ~$10.80으로 절감
- Controlplane/Platform 통합 (2026-05-02): 비용 절감을 위해 Platform 노드(t4g.micro)를 제거하고 Redpanda를 Controlplane으로 통합. Controlplane을 t4g.small로 업그레이드. EBS 1개 절감. 3노드 구성으로 단순화
- Loki 시크릿 Secrets Manager 이관 (2026-04-28): grafana_cloud_logs_url, grafana_cloud_user가 /etc/infra-asset-config에 공백으로 프로비저닝되던 문제 수정. quietchatter-loki-url, quietchatter-loki-user를 Secrets Manager에 등록하고 sync.sh에서 런타임 조회로 변경. IAM 인라인 정책에 두 시크릿 ARN 추가
- Rolling Update 전략 수정 (2026-04-28): Worker 노드 1개 환경에서 maxSurge=1(기본값) 사용 시 업데이트 파드가 Pending 상태로 멈추는 문제 해결. 모든 Deployment(api-gateway, member, book, talk)에 maxSurge: 0, maxUnavailable: 1 적용
- Ghost Node 처리 (2026-04-28): Spot 인스턴스 종료 후 k3s 노드 레코드가 자동 삭제되지 않아 NotReady 노드와 Terminating DaemonSet 파드가 남는 문제 확인. 수동으로 kubectl delete node 처리. AWS Node Termination Handler 도입을 예정 작업으로 등록
- 서비스 템플릿 미동기화 수정 (2026-04-29): 인프라 레벨에서 S3 매니페스트에 Rolling Update 전략을 직접 패치했으나 서비스 서브모듈 k8s/deployment.yaml에는 반영되지 않음. 다음 GitHub Actions 실행 시 변경이 롤백될 수 있었던 문제를 사후 발견. 4개 서비스 템플릿에 strategy 블록 추가 커밋. scripts/sync.sh에도 Loki 시크릿 조회 코드 누락 및 금지 패턴(|| echo "") 존재 확인, S3 원본과 동기화하여 수정
- Secrets Manager 시크릿 통합 (2026-05-02): 9개 개별 시크릿을 단일 JSON 시크릿(quietchatter-secrets)으로 통합. Secrets Manager 비용 $3.60 → $0.40/월 절감. IAM 인라인 정책 Resource를 9개 ARN에서 1개로 축소. sync.sh를 jq 기반 단일 조회 방식으로 변경하고 k8s Secret에 NAVER_CLIENT_ID, NAVER_CLIENT_SECRET, JWT_SECRET_KEY, INTERNAL_SECRET 항목 추가. user_data 3개 템플릿에 dnf install jq 및 k3s_token JSON 파싱 추가. 02-platform data.tf의 db_password 조회를 jsondecode 방식으로 변경
