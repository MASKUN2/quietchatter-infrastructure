---
description: QuietChatter 인프라 구축 전략, 배포 가이드, 현재 상태 및 주요 의사결정 이력을 통합한 단일 문서
---

# Infrastructure Strategy and Status

이 문서는 QuietChatter 프로젝트의 인프라 구축 전략, 배포 가이드, 현재 상태 및 과거의 주요 의사결정 이력을 단일 문서로 통합한 것입니다.
참고: AI 에이전트라면 작업 전 반드시 루트의 AGENTS.md를 먼저 읽으십시오.

## 1. 아키텍처 개요 및 노드 구성 전략

본 인프라는 AWS 환경에서 최소한의 비용으로 마이크로서비스를 안정적으로 운영하기 위해 5노드 구조를 채택합니다.

노드 그룹 구성
- NAT 노드: t4g.nano (0.5GB), 01-base 레이어에서 관리, 프라이빗 서브넷의 인터넷 아웃바운드 라우팅 담당
- Controlplane 노드: t4g.small (2.0GB), Postgres, Redis, Kafka, Consul 구동, 시스템 상태 및 데이터 관리 핵심부
- Gateway 노드: t4g.micro (1.0GB), 퍼블릭 서브넷 배치, EIP 고정, NGINX(80/443 수신) 및 Spring Cloud Gateway(localhost:8080) 동시 구동, JWT 검증 후 내부 라우팅
- Microservices 노드: t4g.micro (1.0GB), 프라이빗 서브넷 배치, 각 마이크로서비스 구동
- Frontend 노드: t4g.micro (1.0GB), 프라이빗 서브넷 배치, Next.js BFF 및 Consul 클라이언트 에이전트 구동

핵심 기술 및 비용 최적화 전략
- 통합 컨트롤 플레인: 관리 서비스와 데이터 저장소를 하나의 노드에 통합하여 인스턴스 유지 비용 최소화
- Consul 에이전트 기반 통신: 각 애플리케이션 노드에 경량 Consul 클라이언트 에이전트를 배치하여 서비스 검색 안정성 및 로컬 헬스 체크 성능 확보
- 안정성 강화: 모든 노드에 2GB 스왑 메모리 설정으로 OOM 방어
- 보안 강화: 22번 포트 차단 및 AWS SSM Session Manager를 통한 무키 접속 환경 구축

JVM 튜닝 가이드라인 (t4g.micro 대응)
- Heap Memory: -Xms256m -Xmx256m
- Metaspace: -XX:MaxMetaspaceSize=128m
- GC: -XX:+UseSerialGC
- Thread Stack: -Xss256k
- Docker Limit: 컨테이너 메모리 제한 450M 권장

예상 비용
- 서울 리전 기준 월 총합 약 26.00 달러
- 초기 설계 대비 약 64퍼센트 비용 절감 달성 (Ingress 노드 제거로 추가 절감)

## 2. 인프라 배포 및 운영 가이드

인프라 프로비저닝
- 테라폼을 사용하여 정의된 리소스를 생성합니다. (terraform init 및 terraform apply)
- 실행 즉시 비용이 발생하며, 생성 완료까지 약 5분에서 10분이 소요됩니다.
- 계층 실행 순서: 01-base → 02-platform → 03-apps

기초 인프라 검증
- SSM 접속: aws ssm start-session 명령으로 각 노드 터미널 접속 확인
- 스왑 메모리: 접속 후 free -h 명령어로 2GB 스왑 활성화 여부 확인
- 인터넷 연결: 프라이빗 노드에서 ping 8.8.8.8 명령으로 NAT 기능 확인

서비스 구동 및 상태 확인
- 도커 상태: controlplane 노드 접속 후 docker ps 명령으로 주요 서비스 구동 확인
- Consul UI: 내부 주소 10.0.101.100의 8500 포트 활성화 여부 확인

## 3. 현재 상태 및 로드맵

고가용성 및 확장성
- 다중 가용 영역 배포: 인스턴스를 서로 다른 AZ에 분산 배치하여 장애 대비

데이터 보호 및 백업 전략
- EBS 자동 스냅샷: aws_dlm_lifecycle_policy 등을 통해 일일 스냅샷 자동화
- DB 덤프 S3 보관: 정기적인 PostgreSQL 데이터 덤프 스크립트 도입

프로비저닝 최적화
- Packer 도입: Custom AMI를 사전 빌드하여 인스턴스 부팅 속도 단축
- 내부 바이너리 관리: S3에서 검증된 바이너리를 내려받도록 개선

보안 강화
- SSL/TLS 적용: EIP 기반 진입점에서 Let's Encrypt 또는 ACM Private CA를 통해 HTTPS 적용
- 세분화된 IAM 정책: 각 노드별로 필요한 최소 권한 전용 IAM Role 생성

관찰성 고도화
- Grafana Alloy 메트릭 추가: Node Exporter 및 Prometheus 메트릭 수집 추가
- Alerting 설정: 임계치 기반 알람 구성

운영 편의성
- sync.sh 위치 변경: 루트 경로 등 접근성 높은 위치로 이동 및 systemd 서비스 수정

완료된 태스크
- Frontend Consul DNS 연동: frontend 서비스가 Consul에 등록되었으며, API Gateway 호출이 고정 IP 대신 Consul DNS(microservice-api-gateway.service.consul)로 변경됨
- 레이어 구조 간소화 (코드 완료, 배포 대기): 6레이어를 3레이어로 통합하는 Terraform 코드 변경 완료. terraform validate 전 레이어 통과. 배포 시 구 레이어 destroy 후 신규 레이어 apply 필요 (docs/superpowers/plans/2026-04-21-layer-restructure.md 참고)

---

## 4. 히스토리 및 의사결정 요약

S3 기반 설정 동기화 구조 전환 (2026-04-19)
- 변경 배경: 테라폼 user_data 렌더링 방식은 설정 변경 시 인스턴스 전체 교체가 필요하여 비효율적이었음
- 도입 구조: 인프라용 공통 S3 버킷(quietchatter-infra-assets)을 생성하고, systemd 타이머로 5분마다 sync.sh를 실행하여 docker-compose 및 config.alloy 등을 동기화하도록 전환
- 효과: 인프라 교체 없이 즉각적인 설정 반영 가능

보안 및 비밀 관리 강화
- 개선 전: user_data에 환경 변수를 평문으로 하드코딩하여 주입
- 개선 후: 01-base 레이어에서 IAM 최소 권한을 부여하고, 부팅 시 AWS Secrets Manager에서 런타임 조회하도록 변경
- 시크릿 태깅: controlplane=true 등의 태그를 통해 sync.sh가 관련 시크릿을 모두 조회하여 환경 변수 파일로 기록하도록 자동화

로깅 관찰성 고도화 및 테라폼 치환 오류 해결
- 문제점: Grafana Alloy가 컨테이너 로그 수집 시 docker 그룹 권한 부족 및 테라폼 정규식 보간 기호 충돌로 인한 메타데이터 유실 발생
- 조치 내역: 설치 스크립트에서 usermod를 통해 alloy 계정에 docker 그룹 부여, user_data 스크립트 이스케이프 구조 수정
- 최적화: loki.relabel 대신 discovery.relabel을 사용하여 도커 컨테이너 이름(service_name)이 정상적으로 라벨링되도록 처리

Consul 서비스 탐색 최적화
- 최적화 배경: Consul 환경의 안정성을 위해 최신 버전 대신 검증된 버전을 사용
- 조치 내역: Consul 버전을 1.15에서 1.14로 다운그레이드, 컨테이너 네트워크 모드를 host로 변경하여 로컬 DNS 해상도 안정성 확보

Frontend 노드 추가 및 Consul DNS 연동 (2026-04-19 ~ 2026-04-21)
- 변경 배경: Next.js BFF 서비스를 인프라에 통합하면서 API Gateway를 고정 IP가 아닌 Consul 서비스 이름으로 호출하도록 개선이 필요했음
- 도입 구조: t4g.micro 노드에 consul-agent와 Next.js BFF 컨테이너를 배치. INTERNAL_API_GATEWAY_URL을 http://microservice-api-gateway.service.consul:8080으로 설정하여 Consul DNS를 통한 동적 라우팅 적용
- 효과: API Gateway IP 변경 시에도 프론트엔드 재배포 없이 자동으로 새 엔드포인트를 찾을 수 있게 됨

레이어 구조 간소화 (2026-04-21)
- 변경 배경: 6개 레이어(01~06)가 학습 목적으로 과도하게 세분화되어 있었으며, 실제 운영에서 독립 배포가 필요하지 않은 레이어들이 존재했음
- 도입 구조: 6레이어를 3레이어로 통합. 02-ingress 레이어를 삭제하고 NGINX를 Gateway 노드에 동거 배치. 04-apps-gateway, 05-apps-microservices, 06-apps-frontend를 03-apps로 통합
- 효과: remote_state 의존성 체인 단순화, terraform apply 횟수 감소, 별도 Ingress 노드(t4g.micro) 제거로 비용 절감

프로비저닝 스크립트 안정화
- 문제점: Amazon Linux 2023 환경에서 dnf 패키지 매니저 캐시 충돌로 도커 설치가 간헐적으로 실패
- 조치 내역: 설치 전 캐시 정리를 수행하고, 실패 시 대기 후 재시도하는 로직 및 스크립트 페일세이프 설정(set -e) 처리 추가로 인프라 프로비저닝 성공률 향상