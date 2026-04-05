# Infrastructure Backlog & Roadmap

이 문서는 현재 인프라 구성에서 보안 및 안정성을 위해 향후 도입이 필요한 기술적 과제들을 정리합니다. (최종 업데이트: 2026-04-05)

## 1. 고가용성 (High Availability) 및 확장성
현재 단일 인스턴스(SPOF) 구조를 개선하여 서비스 중단을 방지해야 합니다.
- **API Gateway ASG 도입**: 현재 단일 EC2인 API Gateway를 Auto Scaling Group으로 전환하고, Application Load Balancer(ALB)를 통해 트래픽을 분산합니다.
- **다중 가용 영역(Multi-AZ) 배포**: 인스턴스들을 서로 다른 AZ(ap-northeast-2a, 2c)에 분산 배치하여 리전 장애에 대비합니다.

## 2. 데이터 보호 및 백업 전략 (Backup)
데이터 유실 방지를 위한 자동화된 백업 체계가 필요합니다.
- **EBS 자동 스냅샷**: AWS Backup 서비스 또는 테라폼의 `aws_dlm_lifecycle_policy`를 사용하여 `/data` 볼륨에 대한 일일 스냅샷을 자동화합니다.
- **DB 덤프 S3 보관**: Control Plane 내 PostgreSQL 데이터를 정기적으로 덤프하여 S3 버킷에 버전 관리와 함께 저장하는 스크립트를 도입합니다.

## 3. 프로비저닝 최적화 (Golden AMI)
현재 User Data에 의존하는 설치 방식은 배포 속도가 느리고 외부 네트워크 장애에 취약합니다.
- **Packer 도입**: Docker, Alloy, 기본 설정이 완료된 Custom AMI를 미리 빌드하여 인스턴스 부팅 속도를 1분 이내로 단축합니다.
- **내부 바이너리 관리**: `curl`로 외부(GitHub 등)에서 바이너리를 직접 받는 대신, 검증된 버전을 S3에 보관하고 내부망을 통해 내려받도록 개선합니다.

## 4. 보안 강화 (Security)
- **[완료] AWS Secrets Manager 연동**: 인스턴스 `user_data`에 평문으로 시크릿을 주입하던 취약점을 개선하여, `01-base` 레이어에서 Secrets Manager에 키를 등록하고 인스턴스 부팅 시 AWS CLI로 런타임 조회하도록 자동화 워크플로우 구축 완료.
- **SSL/TLS 적용**: 현재 80(HTTP) 포트만 사용 중이나, ALB 도입 시 ACM(AWS Certificate Manager)을 통해 HTTPS를 강제하고 보안 그룹을 더 타이트하게 관리합니다.
- **세분화된 IAM 정책**: 현재 사용 중인 `ssm_profile` 외에 각 노드별로 필요한 최소 권한(S3 접근, CloudWatch 기록 등)만 부여하는 전용 IAM Role을 생성합니다.

## 5. 관찰성 (Observability) 고도화
- **Grafana Alloy 메트릭 추가**: 현재 로그(Loki) 중심의 수집을 넘어, Node Exporter 및 Prometheus 메트릭 전송 설정을 추가하여 시스템 자원 모니터링 대시보드를 구축합니다.
- **Alerting 설정**: 임계치 기반의 알람(CPU 90% 이상 등)을 Grafana Cloud에서 설정하여 장애 발생 시 즉각적인 대응이 가능하도록 합니다.
