# CLAUDE.md - infrastructure

이 문서는 Claude Code가 QuietChatter 인프라 모듈을 작업할 때 따라야 할 지침입니다.

루트 프로젝트의 CLAUDE.md에 정의된 공통 원칙을 먼저 확인하십시오.

## 1. 정보 습득 순서 (Mandatory)

작업 시작 전 반드시 수행하십시오.

1. INFRASTRUCTURE.md 읽기.
2. 스킬 목록 확인 후 상황에 맞는 스킬 활성화. (단 작성된 스킬이 실제 프로젝트 상태와 다른경우 중지하고 사용자에게 수정해야한다고 알립니다)

## 2. 작업 원칙

### A. 네트워크 및 보안

- 보안 그룹은 최소 권한 원칙(Least Privilege)을 따름

### B. Terraform 및 IaC 규정

- 리소스 참조: 레이어 간 데이터 전달은 terraform_remote_state 사용
- 명명 규칙: quietchatter- 접두사 필수 사용
- 검증: 코드 수정 후 반드시 terraform validate 실행

### C. 인프라 자산 관리 (S3 Assets)
- `sync.sh`, `docker-compose.yaml`등은 S3 버킷(`quietchatter-infra-assets`)에서 관리됨
- 읽기, 수정시에는 임시경로(./.s3-assets)로 이를 다운받아서 확인후 업로드한다. 단, 커밋을 할때는 제외한다.

## 3. 주요 기술적 교훈 (Lessons Learned)

### A. 프로비저닝 및 변수 처리

- NAT/iptables: 인터페이스 이름 대신 VPC CIDR 대역(var.vpc_cidr)을 기준으로 마스커레이딩 설정
- 변수 이스케이프: Alloy 설정 등에서 $1을 사용할 때 테라폼 템플릿에서 과도하게 이스케이프($$1)하지 않도록 주의 (실제 파일 생성 결과 확인 필수)
- 미사용 변수 정리: templatefile 호출 시 사용하지 않는 변수는 즉시 제거하여 코드 명확성 유지

### B. 권한 및 보안

- Docker 소켓 권한: Grafana Alloy 등 호스트의 Docker 소켓을 사용하는 에이전트는 컨테이너로 실행 시 호스트의 `/var/run/docker.sock`을 볼륨 마운트하여 사용함
- Secret 주입: 모든 민감 정보는 AWS Secrets Manager에 등록 후 `sync.sh`에서 `.env` 파일로 기록하여 Docker Compose 서비스에 주입

### C. Nginx 설정

- 보간(Interpolation) 주의: Nginx 설정의 $host 등은 테라폼 보간 ${}과 구분되므로 안전하나, 쉘 스크립트 내에서 혼용 시 반드시 따옴표('EOF')로 감싸서 보호

