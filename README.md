# QuietChatter Infrastructure

이 저장소는 quietchatter-project를 위한 테라폼 기반의 Infrastructure as Code (IaC) 설정을 포함하고 있습니다.

## 아키텍처 개요

본 인프라는 AWS에서 비용 효율적인 마이크로서비스 아키텍처(MSA)를 구축하도록 설계되었습니다. ARM 기반 인스턴스 사용과 통합 컨트롤 플레인을 통해 운영 비용을 최소화하는 데 집중합니다.

### 주요 설계 원칙

1. 비용 효율성 및 최적화:
    - AWS t4g (ARM) 시리즈 인스턴스를 독점적으로 사용합니다.
    - 관리형 NAT Gateway 대신 직접 구축한 NAT 인스턴스를 사용합니다.
    - DB, Redis, Kafka, Consul을 하나의 controlplane 노드에 통합하여 비용을 절감합니다.
    - 전 노드에 2GB 스왑 메모리를 설정하고, JVM 메모리 튜닝을 통해 저사양 인스턴스의 안정성을 확보합니다.
2. 네트워크 보안 및 접속:
    - 퍼블릭 및 프라이빗 서브넷으로 구성된 VPC를 사용합니다.
    - 22번 포트(SSH)를 차단하고 AWS SSM Session Manager를 통해 보안 접속을 수행합니다.
    - 외부 트래픽은 NGINX 리버스 프록시를 통해 프라이빗 노드로 라우팅됩니다.
3. 서비스 관리 및 관측성:
    - HashiCorp Consul을 이용해 서비스 디스커버리와 설정을 관리합니다.
    - Grafana Cloud와 Grafana Alloy를 사용해 시스템 로그 및 메트릭을 통합 모니터링합니다.

## 인프라 구성 요소

| 구성 요소 | 인스턴스 타입 | 위치 | 설명 |
| :--- | :--- | :--- | :--- |
| NAT / Ingress 노드 | t4g.nano | 퍼블릭 | NAT 기능 및 NGINX 인그레스 라우팅 수행. |
| controlplane 노드 | t4g.small | 프라이빗 | DB, Redis, Kafka, Consul이 통합된 핵심 노드. 15GB EBS 볼륨 사용. |
| API Gateway 노드 | t4g.micro | 프라이빗 | Spring Cloud Gateway (JVM 최적화) 구동. 마이크로서비스 진입점. |
| Application 노드 | t4g.micro | 프라이빗 | 각 마이크로서비스 (JVM 최적화) 구동 예정. |

## 프로젝트 구조

```text
infrastructure/
├── controlplane.tf             # 통합 컨트롤 플레인 (DB, Redis, Kafka, Consul) 설정
├── nat_ingress.tf              # NAT 및 NGINX 인그레스 인스턴스 설정
├── api_gateway.tf              # API 게이트웨이 인스턴스 설정
├── security.tf                 # 보안 그룹 설정
├── vpc.tf                      # VPC 및 네트워크 설정
├── iam.tf                      # SSM 접속을 위한 IAM 권한 설정
├── docs/                       # 인프라 전략 및 설계 문서
└── templates/                  # 도커 컴포즈 등 노드 설정 템플릿
```

## 검증 방법

```bash
terraform init
terraform validate
terraform plan
```
