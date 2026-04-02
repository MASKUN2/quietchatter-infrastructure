# Infrastructure Deployment Roadmap

이 문서는 설계된 인프라를 AWS에 실제 구축하고 검증하기 위한 단계별 가이드를 제공합니다.

## 1. 단계: 인프라 프로비저닝 (Deployment)
테라폼을 사용하여 정의된 리소스를 생성합니다.
```bash
terraform init
terraform apply
```
*주의: 실행 즉시 비용이 발생하며, 생성 완료까지 약 5~10분이 소요됩니다.*

## 2. 단계: 기초 인프라 검증 (Infrastructure Verification)
리소스가 생성된 후 다음 항목을 점검합니다.
- **SSM 접속**: `aws ssm start-session`을 통해 각 노드 터미널 접속 확인.
- **스왑 메모리**: 접속 후 `free -h` 명령어로 2GB 스왑 활성화 여부 확인.
- **인터넷 연결**: 프라이빗 노드에서 `ping 8.8.8.8`을 통해 NAT 기능 확인.

## 3. 단계: 서비스 구동 및 상태 확인 (Service Verification)
controlplane 노드에 접속하여 도커 서비스를 점검합니다.
- **도커 상태**: `docker ps`를 통해 Consul, Postgres, Redis, Redpanda 구동 확인.
- **Consul UI**: 내부 주소 `10.0.101.100:8500` 포트 활성화 여부 확인.

## 4. 단계: 마이크로서비스 연동 (Application Integration)
백엔드 앱 배포 시 다음 설정을 준수합니다.
- **Consul 설정**: `bootstrap.yml`에 Consul 호스트 주소(10.0.101.100) 입력.
- **메모리 설정**: 배포 스크립트 또는 Dockerfile에 전략 문서의 JVM 튜닝 옵션 반드시 포함.

## 5. 사후 관리
- **모니터링**: Grafana Cloud 대시보드를 통해 스왑 메모리 및 CPU 사용량 실시간 관제.
- **비용 모니터링**: AWS Billing 대시보드를 통해 실제 과금 내역이 예상치($32)를 넘는지 주기적 확인.
