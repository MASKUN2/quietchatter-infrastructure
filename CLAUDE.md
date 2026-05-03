# CLAUDE.md - infrastructure

작업 전 README.md를 읽으십시오. 아키텍처 개요, 레이어 구성, 노드 역할, 배포 방식, 의사결정 이력은 README.md에 있습니다.

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

- sync.sh와 k8s 매니페스트는 S3 버킷(s3://quietchatter-infra-assets/controlplane/)에서 관리된다.
- sync.sh와 k8s 매니페스트를 읽거나 수정하기 전에 반드시 S3에서 원본을 내려받아야 한다. 프로젝트 로컬 경로에 있는 동명 파일은 S3와 내용이 다를 수 있으므로 원본으로 신뢰하지 않는다.
  - sync.sh: `aws s3 cp s3://quietchatter-infra-assets/controlplane/sync.sh /tmp/sync_s3.sh --region ap-northeast-2`
  - 매니페스트: `aws s3 sync s3://quietchatter-infra-assets/controlplane/manifests/ /tmp/manifests/ --region ap-northeast-2`
- 읽기/수정이 필요하면 세션 내 임시경로(mktemp -d)로 내려받아 작업하고 업로드한다. 프로젝트 경로 안에 저장하지 않는다.
- 각 마이크로서비스의 k8s/deployment.yaml(IMAGE_PLACEHOLDER 포함 템플릿)이 매니페스트 구조의 원본이다. S3를 직접 수정했다면 반드시 서비스 템플릿에도 반영하고 커밋해야 한다. 그렇지 않으면 다음 GitHub Actions 실행 시 변경이 롤백된다.

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

- Ghost Node: Spot 인스턴스 종료 후 k3s 노드 레코드가 자동 삭제되지 않음. sync.sh가 15분 이상 NotReady인 노드를 자동 삭제한다. 수동 처리가 필요한 경우 kubectl delete node --ignore-not-found 사용 (--force 금지).
- Rolling Update: Worker 노드 단일 구성 시 maxSurge: 0, maxUnavailable: 1 적용 필수. 기본값(maxSurge=1)은 단일 노드에서 Pending 상태로 업데이트가 멈춤

## 문서 업데이트 원칙

인프라 작업 후 아래 기준에 해당하면 이 CLAUDE.md 또는 README.md를 업데이트하십시오.

- 새로운 운영 패턴, 자동화 로직, 또는 수동 절차가 추가된 경우
- 기존 지침이 현재 구현과 달라진 경우 (예: 수동 처리 → 자동화 전환)
- 장애 원인과 조치 방법이 확인되어 재발 방지 지식으로 남길 필요가 있는 경우
