# QuietChatter Infrastructure (Layered)

이 저장소는 quietchatter-project를 위한 계층화된 테라폼 기반의 Infrastructure as Code (IaC) 설정을 포함하고 있습니다.
단일 상태(State) 관리의 리스크를 줄이고, 변경 주기에 따라 인프라를 분리하여 운영 안정성을 높였습니다.

## 프로젝트 구조 및 실행 순서

인프라는 의존성에 따라 5개의 계층으로 분리되어 있으며, 아래 순서대로 실행해야 합니다.

| 순서 | 디렉토리 | 설명 | 주요 리소스 |
| :--- | :--- | :--- | :--- |
| 1 | `layers/01-base` | 기초 인프라 | VPC, Subnets, 모든 Security Groups, IAM Roles |
| 2 | `layers/02-network-services` | 네트워크 연결성 | NAT Instance, Ingress NGINX, Private Routing |
| 3 | `layers/03-platform` | 공통 플랫폼 | Control Plane (DB, Kafka, Consul), EBS Volume |
| 4 | `layers/04-apps-gateway` | 서비스 게이트웨이 | API Gateway Instance (정적 IP 할당) |
| 5 | `layers/05-apps-microservices`| 마이크로서비스 | Microservices ASG (Book, Member, Talk, Customer) |

## 실행 방법

**[중요] 시크릿 통합 관리**: 데이터베이스 비밀번호, Grafana 토큰 등의 민감한 시크릿 정보는 오직 `layers/01-base`의 `terraform.tfvars` 파일에서만 정의합니다. 생성된 시크릿은 AWS Secrets Manager에 안전하게 보관되며, 하위 계층들은 부팅 시(User Data) 안전하게 시크릿을 조회합니다. 다른 계층에서는 변수 파일을 따로 관리할 필요가 없습니다.

각 계층 디렉토리로 이동하여 다음 명령어를 순서대로 실행합니다.

```bash
# 1. 기초 인프라 및 시크릿(Secrets Manager) 생성
cd layers/01-base
terraform init
terraform apply -auto-approve

# 2. 하위 계층 순차 배포 (시크릿 파일 불필요)
cd ../02-network-services
terraform init
terraform apply -auto-approve

cd ../03-platform
terraform init
terraform apply -auto-approve
... (순서대로 진행)
```

## 계층화 설계 원칙

1. **상태 분리 (State Separation)**: 각 계층은 독립된 `terraform.tfstate`를 가집니다. 이를 통해 특정 마이크로서비스 변경 시 VPC나 데이터베이스가 영향받는 리스크를 방지합니다.
2. **의존성 관리 (Remote State)**: 하위 계층은 `data "terraform_remote_state"`를 통해 상위 계층의 리소스 ID를 참조합니다.
3. **순환 의존성 해제 (Decoupling)**: API Gateway와 Control Plane에 정적 프라이빗 IP를 할당하여, NAT/Ingress 인스턴스가 이들의 생성 완료를 기다리지 않고도 설정을 완료할 수 있도록 설계했습니다.

## 구성 요소 정보

| 구성 요소 | 인스턴스 타입 | 위치 | 설명 |
| :--- | :--- | :--- | :--- |
| NAT / Ingress 노드 | t4g.nano | 퍼블릭 | NAT 기능 및 NGINX 인그레스 라우팅 (정적 IP 참조) |
| controlplane 노드 | t4g.small | 프라이빗 | DB, Redis, Kafka, Consul 통합 노드 (정적 IP: 10.0.101.100) |
| API Gateway 노드 | t4g.micro | 프라이빗 | Spring Cloud Gateway (정적 IP: 10.0.101.200) |
| Microservices | t4g.micro | 프라이빗 | Auto Scaling Group을 통한 개별 서비스 배포 |
