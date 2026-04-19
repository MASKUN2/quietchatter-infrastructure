# CLAUDE.md - infrastructure

이 문서는 Claude Code가 QuietChatter 인프라 모듈을 이해하고 관리하기 위한 지침입니다.

루트 프로젝트의 CLAUDE.md에 정의된 공통 원칙 및 인프라 작업 순서를 먼저 확인하십시오.

## 1. 정보 습득 순서 (Mandatory)

모든 작업 시작 전 및 작업 중에 superpowers 스킬 목록을 항상 확인하고 상황에 맞는 스킬을 활성화하여 사용하십시오.

작업을 시작하기 전, 반드시 다음 순서로 프로젝트 문맥을 파악해야 합니다.

1. CLAUDE.md (현재 문서): 아키텍처 원칙 및 작업 규정 확인
2. docs/update-log-*.md: 최근 변경 사항 및 현재 인프라 상태 파악 (가장 최신 파일 우선)
3. docs/architecture-strategy.md: 전체적인 시스템 설계 의도 파악

## 2. 아키텍처 및 작업 원칙

### A. 비용 최적화 및 안정성

- AWS t4g (ARM64) 전용: nano (NAT), micro (App), small (DB/Kafka) 사양 준수
- 모든 노드에 2GB 스왑 메모리 설정 필수
- Java 앱: SerialGC 및 고정 힙 메모리 설정 사용

### B. 네트워크 및 보안

- 모든 프라이빗 노드는 NAT 인스턴스를 경유함
- SSH 대신 AWS SSM Session Manager를 통한 접속만 허용
- 보안 그룹은 최소 권한 원칙(Least Privilege)을 따름

### C. Terraform 및 IaC 규정

- 계층 구조 준수: 01-base ~ 05-apps-microservices 순서 및 디렉토리 구분
- 리소스 참조: 레이어 간 데이터 전달은 terraform_remote_state 사용
- 명명 규칙: quietchatter- 접두사 필수 사용
- 검증: 코드 수정 후 반드시 terraform validate 실행

## 3. 주요 기술적 교훈 (Lessons Learned)

### A. 프로비저닝 및 변수 처리

- NAT/iptables: 인터페이스 이름 대신 VPC CIDR 대역(var.vpc_cidr)을 기준으로 마스커레이딩 설정
- User Data 안정성: Bash 내에서 설정 파일 생성 시 cat <<'EOF' (따옴표 필수)를 사용하여 변수의 의도치 않은 치환 방지
- 변수 이스케이프: Alloy 설정 등에서 $1을 사용할 때 테라폼 템플릿에서 과도하게 이스케이프($$1)하지 않도록 주의 (실제 파일 생성 결과 확인 필수)
- 미사용 변수 정리: templatefile 호출 시 사용하지 않는 변수는 즉시 제거하여 코드 명확성 유지

### B. 권한 및 보안

- Docker 소켓 권한: Grafana Alloy 등 호스트의 Docker 소켓을 사용하는 에이전트는 반드시 docker 그룹에 추가되어야 함 (usermod -aG docker alloy)
- Secret 주입: 모든 민감 정보는 AWS Secrets Manager에 등록 후 user_data에서 부팅 시 조회하여 환경 변수로 주입

### C. Nginx 설정

- 보간(Interpolation) 주의: Nginx 설정의 $host 등은 테라폼 보간 ${}과 구분되므로 안전하나, 쉘 스크립트 내에서 혼용 시 반드시 따옴표('EOF')로 감싸서 보호

### D. S3 기반 설정 동기화 (sync.sh)

- sync.sh 경로: 현재 `/usr/local/bin/sync.sh`. SSM 접속 시 ec2-user 홈에서 보이지 않아 장애 대응이 불편하므로, 향후 `/home/ec2-user/sync.sh`로 이동 예정.
- /etc/sysconfig/alloy 구성: Alloy systemd 서비스는 `CONFIG_FILE` 환경변수가 없으면 "accepts 1 arg(s), received 0" 오류로 실패함. sync.sh가 `/etc/sysconfig/alloy`를 덮어쓸 때 반드시 `CONFIG_FILE=/etc/alloy/config.alloy`를 포함해야 함.
- 파일 소유권: sync.sh가 root로 실행되면 `/home/ec2-user/` 하위 파일이 root 소유로 생성됨. 이후 ec2-user로 실행 시 덮어쓰기 실패(Permission denied). 파일 생성 후 반드시 `chown ec2-user:ec2-user`를 실행할 것.
- 임시 파일: `mktemp`는 기본값(`/tmp/`)을 사용. `~` 경로를 지정하면 실행 주체(root)의 홈인 `/root/`가 되어 의도와 다름. 최종 파일만 `/home/ec2-user/`에 배치할 것.

### E. Grafana Alloy 로그 수집

- Docker 컨테이너 로그에서 `service_name` 레이블을 매핑할 때 `loki.relabel`에서 `__meta_docker_container_name`을 참조하면 항상 빈 값이 됨. `loki.source.docker`는 로그 엔트리 포워드 시 `__meta_*` 레이블을 전달하지 않기 때문.
- 올바른 방법: `discovery.relabel`에서 타겟 단계에 `service_name` 레이블을 설정하고, `loki.source.docker`의 `targets`에 `discovery.relabel.*.output`을 사용. `__` 없는 레이블은 로그 엔트리에 그대로 첨부됨.

```hcl
discovery.relabel "docker" {
  targets = discovery.docker.linux.targets
  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    replacement   = "$1"
    target_label  = "service_name"
  }
}
loki.source.docker "logs" {
  targets    = discovery.relabel.docker.output
  ...
}
```
