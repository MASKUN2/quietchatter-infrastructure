# QuietChatter Infrastructure

이 저장소는 quietchatter-project를 위한 테라폼 기반의 Infrastructure as Code (IaC) 설정을 포함하고 있습니다.

## 아키텍처 개요

본 인프라는 AWS에서 비용 효율적인 마이크로서비스 아키텍처(MSA)를 구축하도록 설계되었습니다. ARM 기반 인스턴스 사용과 영구 저장 계층의 통합을 통해 운영 비용을 최소화하는 데 집중합니다.

### 주요 설계 원칙

1. 비용 효율성:
    - AWS t4g (ARM) 시리즈 인스턴스를 독점적으로 사용합니다.
    - 관리형 AWS NAT Gateway 대신 직접 구축한 NAT 인스턴스를 사용합니다.
    - PostgreSQL, Redpanda (Kafka 대체), Redis를 단일 Persistence 노드에 통합하여 운영합니다.
2. 네트워크 보안:
    - 퍼블릭 및 프라이빗 서브넷으로 구성된 VPC를 사용합니다.
    - 모든 API 노드와 데이터베이스는 프라이빗 서브넷에 위치합니다.
    - 외부 유입 트래픽은 퍼블릭 서브넷에 위치한 NAT 인스턴스의 NGINX 리버스 프록시를 통해 관리됩니다.
3. 데이터 안전성:
    - Persistence 노드의 데이터를 15GB 크기의 독립적인 EBS 볼륨에 분리하여 저장합니다.
    - 인스턴스가 재생성되더라도 데이터 볼륨을 다시 마운트하여 데이터 유실을 방지합니다.

## 인프라 구성 요소

| 구성 요소 | 인스턴스 타입 | 위치 | 설명 |
| :--- | :--- | :--- | :--- |
| NAT / Ingress 노드 | t4g.nano | 퍼블릭 서브넷 | 프라이빗 서브넷을 위한 NAT 기능 및 NGINX 인그레스 라우팅 수행. Docker로 NGINX 실행. |
| API Gateway 노드 | t4g.micro | 프라이빗 서브넷 | 마이크로서비스의 진입점. NGINX로부터 트래픽 수신. Docker 설치 완료. |
| Persistence 노드 | t4g.small | 프라이빗 서브넷 | PostgreSQL, Redpanda, Redis가 통합된 노드. 15GB EBS 볼륨 사용. Docker Compose로 관리. |
| 마이크로서비스 | t4g.micro | 프라이빗 서브넷 | microservice-book, microservice-user 등을 위한 개별 노드 (향후 ASG 구성 예정). |

## 프로젝트 구조

```text
infrastructure/
├── providers.tf                # AWS 프로바이더 설정
├── variables.tf                # 리전 및 CIDR 정의
├── vpc.tf                      # VPC, 서브넷 및 라우팅 설정
├── nat_ingress.tf              # NAT 및 NGINX 인그레스 인스턴스 설정
├── security.tf                 # 보안 그룹 설정
├── api_gateway.tf              # API 게이트웨이 인스턴스 설정
├── persistence.tf              # 통합 데이터 저장소 노드 설정
├── docker-compose.*.yaml       # 노드별 서비스 구성 파일
└── outputs.tf                  # 리소스 ID 및 IP 출력
```

## 검증 방법

배포 전 구문을 확인하고 실행 계획을 보려면 다음 명령을 사용합니다:

```bash
# 테라폼 초기화
terraform init

# 구문 확인
terraform validate

# 실행 계획 확인
terraform plan
```

주의: 이 저장소는 인프라 문서화 및 아키텍처 검증을 목적으로 합니다. 실제 배포는 주의해서 진행해야 합니다.
