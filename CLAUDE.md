# CLAUDE.md - infrastructure

작업 전 INFRASTRUCTURE.md를 읽으십시오. 아키텍처 개요, 레이어 구성, 노드 역할, 배포 방식, 의사결정 이력은 INFRASTRUCTURE.md에 있습니다.

루트 프로젝트의 CLAUDE.md에 정의된 공통 원칙도 확인하십시오.

스킬 목록을 확인하고 상황에 맞는 스킬을 활성화하십시오. 스킬 내용이 실제 프로젝트 상태와 다른 경우 중지하고 사용자에게 알립니다.

## 작업 원칙

### A. 네트워크 및 보안

- 보안 그룹은 최소 권한 원칙(Least Privilege)을 따름

### B. Terraform 및 IaC 규정

- 리소스 참조: 레이어 간 데이터 전달은 terraform_remote_state 사용
- 명명 규칙: quietchatter- 접두사 필수 사용
- 검증: 코드 수정 후 반드시 terraform validate 실행

### C. 인프라 자산 관리 (S3 Assets)

- sync.sh, k8s 매니페스트(manifests/)는 S3 버킷(quietchatter-infra-assets)에서 관리됨
- 읽기/수정 시 임시경로(./.s3-assets)로 다운받아 확인 후 업로드한다. 커밋 시에는 제외한다.

## 기술적 교훈 (Lessons Learned)

### 프로비저닝 및 변수 처리

- NAT/iptables: 인터페이스 이름 대신 VPC CIDR 대역(var.vpc_cidr)을 기준으로 마스커레이딩 설정
- 변수 이스케이프: Alloy 설정 등에서 $1을 사용할 때 테라폼 템플릿에서 과도하게 이스케이프($$1)하지 않도록 주의
- 미사용 변수 정리: templatefile 호출 시 사용하지 않는 변수는 즉시 제거

### 권한 및 보안

- Secret 주입: 모든 민감 정보는 AWS Secrets Manager에 등록. sync.sh에서 조회 후 kubectl create secret으로 k8s Secret 오브젝트로 변환하여 파드에 환경변수로 주입
- Secrets Manager 조회 시 `|| echo ""` 폴백 금지. 조회 실패가 빈 문자열로 숨겨지면 앱이 내부 기본값(예: "root")으로 동작하는 장애가 발생함

### Nginx 설정

- 보간(Interpolation) 주의: 쉘 스크립트 내에서 Nginx $host와 테라폼 ${} 혼용 시 반드시 따옴표('EOF')로 감싸서 보호

### k8s 노드 라벨링

- k8s-node-labeling 스킬 참조. 노드 라벨, nodeSelector, ROLES 컬럼 관련 작업 시 반드시 확인

### k8s 운영

- Ghost Node: Spot 인스턴스 종료 후 k3s 노드 레코드가 자동 삭제되지 않음. NotReady 노드가 남아 있으면 수동으로 kubectl delete node 처리 필요
- Rolling Update: Worker 노드 단일 구성 시 maxSurge: 0, maxUnavailable: 1 적용 필수. 기본값(maxSurge=1)은 단일 노드에서 Pending 상태로 업데이트가 멈춤
