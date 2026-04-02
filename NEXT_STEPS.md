# 인프라 고도화 및 MSA 전환 계획 (Infrastructure Next Steps)

이 계획 문서는 현재 테라폼으로 구성된 AWS 인프라(t4g ARM 기반, 통합 Persistence 노드 등)를 바탕으로, Spring Cloud 기반 마이크로서비스 배포를 위한 추가 인프라 구축 및 보안/관측성 강화 작업 단계를 정의합니다.

## 1. 개요 및 목표

기존 인프라 전략 문서(2026-04-02_Spring_Cloud_Infrastructure_Strategy.md)에 명시된 향후 과제를 완수하고, 안전한 접속 환경(AWS SSM) 및 관측성(Grafana Alloy) 기반을 인프라 전반에 걸쳐 구성합니다.

## 2. 세부 구현 단계 (Implementation Steps)

### 단계 1: AWS Systems Manager (SSM) 접속 환경 구성
- 목표: SSH(22번) 포트 노출 없이 EC2에 안전하게 접속하기 위한 IAM 역할(Role) 및 인스턴스 프로파일 생성
- 작업 대상 파일: infrastructure/iam.tf (신규 생성)
- 작업 내용:
  - AmazonSSMManagedInstanceCore 정책이 포함된 공통 IAM Role 생성
  - 이를 활용한 IAM Instance Profile 생성

### 단계 2: Spring Cloud Management 노드 구축
- 목표: Eureka(Discovery Server), Config Server, Admin Server 구동을 위한 전용 노드 구축
- 작업 대상 파일: infrastructure/management.tf (신규 생성)
- 작업 내용:
  - t4g.micro 인스턴스 타입으로 Management 노드 정의
  - 프라이빗 서브넷에 정적 IP를 할당하여 서비스 탐색 안정성 확보
  - 신규 생성한 SSM 인스턴스 프로파일(iam.tf) 연결
  - User Data에 SSM 에이전트 및 Docker/Docker Compose 설치 스크립트 추가
  - NAT 라우팅이 설정된 후 생성되도록 depends_on (aws_route.private_nat_route) 의존성 추가

### 단계 3: 기존 노드에 SSM 프로파일 및 에이전트 적용
- 목표: NAT, API Gateway, Persistence 노드 등 기존 노드를 SSM으로 접속할 수 있도록 업데이트
- 작업 대상 파일: infrastructure/nat_ingress.tf, infrastructure/api_gateway.tf, infrastructure/persistence.tf
- 작업 내용:
  - 기존 EC2 리소스 선언에 iam_instance_profile 연결 구문 추가
  - 각 인스턴스의 User Data 스크립트에 SSM 에이전트 설치 및 활성화 코드 보강

### 단계 4: 보안 그룹 규칙 점검 및 관측성 통신 지원
- 목표: 불필요한 포트 차단 유지 및 관측성(Observability) 에이전트 배포 준비
- 작업 대상 파일: infrastructure/security.tf, 각종 docker-compose 파일
- 작업 내용:
  - security.tf 내에서 22번 포트가 완전히 제거되어 있는지 재확인(현재 제거된 상태이나 변경 방지)
  - Grafana Alloy 구동을 위해 필요한 환경 변수나 설정 파일을 관리할 템플릿 준비

## 3. 검증 및 테스트 계획 (Verification & Testing)

1. 테라폼 문법 검증: terraform validate 및 terraform plan 명령을 통해 인프라 코드의 구문 오류와 생성될 리소스를 확인합니다.
2. SSM 접속 테스트: 리소스 배포 후, AWS CLI 세션 매니저를 통해 각 노드(NAT, API Gateway, Persistence, Management)에 SSH 키 없이 정상 접속되는지 확인합니다.
3. IP 할당 검증: Management 노드와 Persistence 노드가 프라이빗 서브넷에서 고정된 정적 IP를 정상적으로 획득했는지 확인합니다.
