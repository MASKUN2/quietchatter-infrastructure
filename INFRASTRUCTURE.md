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

본 인프라는 AWS 환경에서 최소한의 비용으로 마이크로서비스를 안정적으로 운영하기위한 구조를 채택합니다.

- 통합 컨트롤 플레인: 관리 서비스와 데이터 저장소를 하나의 노드에 통합하여 인스턴스 유지 비용 최소화
- Consul 에이전트 기반 통신: 각 애플리케이션 노드에 경량 Consul 클라이언트 에이전트를 배치하여 서비스 검색 안정성 및 로컬 헬스 체크 성능 확보
- 안정성 강화: 모든 노드에 2GB 스왑 메모리 설정으로 OOM 방어
- 보안 강화: 22번 포트 차단 및 AWS SSM Session Manager를 통한 무키 접속 환경 구축

## 레이어 구성

- 01-base
	- NAT 노드: 프라이빗 서브넷 인터넷 아웃바운드 라우팅, iptables VPC CIDR 마스커레이딩

- 02-platform
	- Controlplane 노드: Postgres, Redis, Kafka, Consul 구동. 시스템 상태 및 데이터 관리 핵심부

- 03-apps
	- Gateway 노드: 퍼블릭 서브넷, EIP 고정, NGINX + Spring Cloud Gateway, JWT 검증 후 내부 라우팅
	- Microservices 노드: 프라이빗 서브넷, 각 마이크로서비스 구동

## 예상 비용

- 서울 리전 기준 월 총합 약 26.00 달러

---

# 2. 히스토리 및 의사결정 요약

## 예정 작업

- [나중에]고가용성: 다중 AZ 배포
- 데이터 보호: EBS 일일 스냅샷, PostgreSQL 덤프 S3 보관
- 프로비저닝 최적화: Packer Custom AMI, S3 검증 바이너리
- 보안: Let's Encrypt/ACM HTTPS 적용, 노드별 IAM Role 세분화
- 관찰성: Node Exporter/Prometheus 메트릭 수집, 임계치 알람 구성
- 운영: sync.sh를 /home/ec2-user/로 이동

## 과거 의사결정

- S3 동기화 구조 전환 (2026-04-19): user_data 방식 → systemd 타이머 + sync.sh + S3 버킷(quietchatter-infra-assets). 인프라 교체 없이 설정 즉시 반영
- 비밀 관리 강화: 평문 환경변수 → AWS Secrets Manager 런타임 조회. 태그 기반 자동 조회
- Grafana Alloy 로깅 안정화: alloy 계정에 docker 그룹 추가, discovery.relabel로 service_name 라벨링 정상화
- Consul 안정화: 1.15 → 1.14 다운그레이드, 컨테이너 네트워크 모드 host로 변경
- Frontend 노드 제거 (2026-04-26): Next.js BFF 인프라 자원 및 설정 전면 삭제
- 레이어 6→3 통합 (2026-04-21): 02-ingress 제거, 04~06-apps → 03-apps. remote_state 단순화 및 비용 절감
- 프로비저닝 안정화: dnf 캐시 충돌 해결, 재시도 로직 및 set -e 적용
