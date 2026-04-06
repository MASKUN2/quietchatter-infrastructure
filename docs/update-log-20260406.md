# 인프라 업데이트 로그 - 2026-04-06

## 1. Consul 버전 다운그레이드 및 네트워크 최적화
시스템 전반에서 사용 중인 Consul 버전을 1.15에서 1.14로 변경하고, 네트워크 설정을 최적화했습니다.

### 수정 사항
- **버전 다운그레이드**: 모든 `docker-compose` 템플릿의 Consul 이미지를 1.14로 변경.
- **인터페이스 명시**: Amazon Linux 2023(Nitro 인스턴스)의 기본 인터페이스인 `ens5`를 `CONSUL_BIND_INTERFACE`로 명시.
- **호스트 네트워크 모드**: API Gateway 및 Control Plane의 Consul 설정에 `network_mode: host` 적용으로 서비스 탐색 안정성 강화.

## 2. User Data 프로비저닝 안정화 및 가시성 개선
인스턴스 초기화 스크립트(`user_data.sh.tftpl`)의 구조를 전면 개편하여 배포 성공률을 높였습니다.

### 수정 사항
- **로깅 및 에러 핸들링**: `log()` 함수와 `error_handler()`를 도입하여 초기화 과정을 추적하고 오류 발생 시 즉시 중단되도록 개선.
- **상태 지속성**: 시크릿 정보를 `/home/ec2-user/.env` 파일에 저장하여 인스턴스 재시작 후에도 환경 변수를 유지할 수 있도록 설계.
- **단계별 구조화**: 인터넷 연결 확인(Step 0)부터 서비스 실행(Step 7)까지 명확한 단계별 실행 구조 확립.

## 3. IaC 코드 품질 및 유지보수성 향상
테라폼 코드의 가독성을 높이고 운영 자동화를 위한 설정을 추가했습니다.

### 수정 사항
- **Locals 활용**: `controlplane.tf` 및 `api_gateway.tf`에서 복잡한 템플릿 렌더링 로직을 `locals` 블록으로 분리하여 가독성 개선.
- **자동 교체 설정**: `user_data_replace_on_change = true`를 추가하여 설정 변경 시 수동 작업 없이 인스턴스가 자동으로 재생성되도록 개선.
- **AGENTS.md 개편**: 프로젝트의 SSOT(Single Source of Truth)인 가이드 문서를 더 체계적으로 구조화하고 정보 습득 순서 강제.

## 4. 보안 및 비밀 관리 강화 (Security Enhancements)
민감한 정보를 테라폼 변수에서 직접 전달하는 대신, 런타임에 AWS Secrets Manager를 통해 안전하게 주입하도록 개선했습니다.

### 수정 사항
- **비밀번호 주입 방식 변경**: `DB_PASSWORD`를 `user_data` 내에서 `aws secretsmanager` 명령으로 직접 조회하여 주입.
- **환경 변수 보호**: 조회된 비밀번호를 `.env` 파일(권한 600)로 저장하고 Docker Compose 실행 시 `--env-file` 옵션으로 참조하여 보안성 확보.
- **코드 결합도 완화**: `variables.tf` 내의 하드코딩된 민감 정보를 제거하고, `terraform_remote_state`를 통한 동적 참조로 전면 개편.

### 적용 방법
테라폼 apply 실행 시 인스턴스가 교체될 수 있으므로, 서비스 중단 시간을 고려하여 배포를 진행해야 합니다. 특히 Control Plane 교체 시 EBS 볼륨 마운트 과정을 주의 깊게 모니터링하십시오.
