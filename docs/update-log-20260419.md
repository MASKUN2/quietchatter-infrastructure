# 인프라 업데이트 로그 - 2026-04-19

## 1. Redpanda 스키마 레지스트리 활성화 및 포트 노출
마이크로서비스에서 아브로(Avro) 등 스키마 기반 메시징을 지원하기 위해 Redpanda의 스키마 레지스트리를 활성화했습니다.

### 수정 사항
- **Docker Compose 템플릿 수정**: `infrastructure/layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl` 파일에서 Redpanda 서비스의 실행 커맨드에 `--schema-registry-addr` 및 `--advertise-schema-registry-addr` 옵션 추가.
- **포트 노출**: 컨테이너의 8081 및 18081 포트를 호스트에 노출하도록 설정.
- **보안 그룹 업데이트**: `infrastructure/layers/01-base/security.tf`에서 `controlplane` 보안 그룹에 8081 및 18081 포트 인바운드 규칙 추가 (microservices 및 api_gateway SG로부터의 접근 허용).

### 적용 방법
테라폼 `01-base` 및 `03-platform` 레이어에 대해 `terraform apply`를 실행해야 합니다. `controlplane` 인스턴스의 `user_data`가 변경되었으므로 인스턴스가 자동으로 교체될 수 있습니다. EBS 볼륨 마운트 및 데이터 보존 상태를 확인하십시오.
