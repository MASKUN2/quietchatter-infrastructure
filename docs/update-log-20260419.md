# 인프라 업데이트 로그 - 2026-04-19

## 1. Redpanda 스키마 레지스트리 활성화 및 포트 노출
마이크로서비스에서 아브로(Avro) 등 스키마 기반 메시징을 지원하기 위해 Redpanda의 스키마 레지스트리를 활성화했습니다.

### 수정 사항
- **Docker Compose 템플릿 수정**: `infrastructure/layers/03-platform/templates/docker-compose.controlplane.yaml.tftpl` 파일에서 Redpanda 서비스의 실행 커맨드에 `--schema-registry-addr` 및 `--advertise-schema-registry-addr` 옵션 추가.
- **포트 노출**: 컨테이너의 8081 및 18081 포트를 호스트에 노출하도록 설정.
- **보안 그룹 업데이트**: `infrastructure/layers/01-base/security.tf`에서 `controlplane` 보안 그룹에 8081 및 18081 포트 인바운드 규칙 추가 (microservices 및 api_gateway SG로부터의 접근 허용).

### 적용 방법
테라폼 `01-base` 및 `03-platform` 레이어에 대해 `terraform apply`를 실행해야 합니다. `controlplane` 인스턴스의 `user_data`가 변경되었으므로 인스턴스가 자동으로 교체될 수 있습니다. EBS 볼륨 마운트 및 데이터 보존 상태를 확인하십시오.

## 2. Frontend Consul DNS 연동 및 Gateway 이름 일괄 변경
Next.js BFF (frontend) 서비스의 서비스 검색(Service Discovery) 기능을 강화하고, API Gateway의 식별자를 보다 명확한 `microservice-api-gateway`로 변경했습니다.

### 수정 사항
- **Gateway 이름 변경**: `layers/04-apps-gateway` 및 `layers/03-platform`의 기본 도커 이미지 이름을 `microservice-api-gateway`로 업데이트하고, 게이트웨이 컨테이너에 `SPRING_APPLICATION_NAME=microservice-api-gateway`를 주입하여 Consul 등록 이름을 일치시켰습니다.
- **Frontend Consul 등록**: `layers/06-apps-frontend/templates/user_data.sh.tftpl`에 Consul 서비스 정의 파일(`frontend.json`) 생성 단계를 추가하여 `microservice-frontend` 서비스를 Consul에 등록했습니다.
- **Consul DNS 연동**: Frontend 노드에서 `systemd-resolved` 설정을 통해 `~consul` 도메인 조회를 Consul DNS(127.0.0.1:8600)로 라우팅하도록 설정했습니다.
- **DNS 기반 호출**: Frontend 앱의 `INTERNAL_API_GATEWAY_URL`을 고정 IP에서 `http://microservice-api-gateway.service.consul:8080`으로 변경했습니다.

### 적용 방법
테라폼 `03-platform`, `04-apps-gateway`, `06-apps-frontend` 레이어에 대해 `terraform apply`를 실행해야 합니다. 특히 Frontend 인스턴스는 `user_data` 변경으로 인해 인스턴스가 교체됩니다.
