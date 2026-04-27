---
description: QuietChatter 인프라 구축 전략, 배포 가이드, 현재 상태 및 주요 의사결정 이력을 통합한 단일 문서
user-review:
instruction: 
	- 섹션구조 레벨을 #, ## 까지만 허용
	- "# 2. 히스토리 및 의사결정 요약" 은 매 작업마다 압축하십시오.
	- frontmatter "user-review" 에 대한 작업이 완료된 경우, 리뷰 내용만 지움.
	
---

# 1. 아키텍처 개요

## 목적 및 전략

본 인프라는 AWS 환경에서 최소한의 비용으로 마이크로서비스를 k3s 클러스터로 운영하기 위한 구조를 채택합니다.

- 단일 k3s 클러스터: Controlplane(서버) + Platform(에이전트) + Gateway(에이전트) + Worker ASG(에이전트) 4노드 구성
- 서비스 디스커버리: k3s 내장 CoreDNS, 서비스 이름 기반 DNS(service.namespace.svc.cluster.local)
- 안정성 강화: 모든 노드에 2GB 스왑 메모리 설정으로 OOM 방어
- 보안 강화: 22번 포트 차단 및 AWS SSM Session Manager를 통한 무키 접속 환경 구축

## 레이어 구성

- 01-base
	- NAT 노드: 프라이빗 서브넷 인터넷 아웃바운드 라우팅, iptables VPC CIDR 마스커레이딩
	- 공통 기반: 전체 레이어 보안 그룹, IAM/SSM 프로파일, Secrets Manager 시크릿, S3 자산 버킷 관리
	- k3s 클러스터 토큰: Secrets Manager에 저장, 모든 노드 부팅 시 조회

- 02-platform
	- Controlplane 노드(t4g.micro): k3s server, Redis StatefulSet 구동
	- Platform 노드(t4g.micro): k3s agent, Redpanda StatefulSet 전용 실행
	- RDS PostgreSQL: AWS 관리형 db.t4g.micro, 프라이빗 서브넷 배치

- 03-apps
	- Gateway 노드(t4g.micro, 퍼블릭): k3s agent, EIP 고정. NGINX(HostNetwork) + Spring Cloud Gateway Pod
	- Worker ASG(t4g.small, Spot-only, min=1/max=3): k3s agent. 4개 마이크로서비스 Pod 통합 실행. CPU 70% 초과 시 자동 스케일아웃

## 워크로드 배포 방식

매니페스트는 S3(s3://quietchatter-infra-assets/controlplane/manifests/)에서 관리된다.
Controlplane의 systemd timer(5분 주기)가 sync.sh를 실행하여 kubectl apply로 변경을 반영한다.

## 예상 비용

- 서울 리전 기준 월 총합 약 10.80 달러 (4노드: controlplane t4g.micro + platform t4g.micro + gateway t4g.micro + worker t4g.small Spot)

---

# 2. 히스토리 및 의사결정 요약

## 예정 작업

- [나중에]고가용성: 다중 AZ 배포
- 데이터 보호: EBS 일일 스냅샷, PostgreSQL 덤프 S3 보관
- 프로비저닝 최적화: Packer Custom AMI, S3 검증 바이너리
- 보안: Let's Encrypt/ACM HTTPS 적용, 노드별 IAM Role 세분화
- 관찰성: Node Exporter/Prometheus 메트릭 수집, 임계치 알람 구성
- 운영: sync.sh를 /home/ec2-user/로 이동

## 비표준 구현 및 표준 대안

현재 구현이 업계 표준과 다른 부분과 그 대안을 기록한다.

워크로드 배포(sync.sh S3 폴링):
- 현재: controlplane systemd 타이머가 5분마다 S3에서 매니페스트를 받아 kubectl apply
- 표준: ArgoCD 또는 Flux (GitOps). Git 저장소를 직접 감시하다 변경 즉시 반영. 배포 이력 추적 및 롤백 UI 제공
- 채택 이유: 포트폴리오 규모에서 ArgoCD 운영 비용(메모리, 복잡도) 대비 효용이 낮아 단순화

시크릿 주입(sync.sh 수동 변환):
- 현재: sync.sh가 AWS Secrets Manager 값을 조회해 kubectl create secret으로 k8s Secret을 직접 생성
- 표준: External Secrets Operator(ESO). k8s CRD로 선언하면 ESO가 Secrets Manager를 감시하며 자동 동기화
- 채택 이유: ESO 설치 및 CRD 관리 복잡도 대비 소규모 시크릿 수가 적어 현재는 수동으로 충분

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
