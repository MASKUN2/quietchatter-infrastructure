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

## 3. S3 기반 설정 동기화 구조로 전환

로컬 Terraform 템플릿으로 config.alloy, docker-compose.yaml 등을 렌더링하던 방식을 폐기하고, S3에 파일을 직접 관리하며 sync.sh가 주기적으로 내려받는 구조로 전환했습니다.

### 배경
기존 방식은 설정 변경 시 terraform apply로 인스턴스를 교체해야 했습니다. 새 구조에서는 S3 파일만 업데이트하면 5분 이내에 모든 인스턴스에 반영됩니다.

### S3 버킷 구조
버킷: `quietchatter-infra-assets`

```
ingress/
  scripts/sync.sh
  config/docker-compose.yaml
  config/config.alloy
  config/nginx.conf
controlplane/
  scripts/sync.sh
  config/docker-compose.yaml
  config/config.alloy
  config/init-db.sql
gateway/
  scripts/sync.sh
  config/docker-compose.yaml
  config/config.alloy
microservices/
  scripts/sync.sh
  config/docker-compose.yaml (app_name별)
  config/config.alloy
```

### 제거된 파일
- `layers/02-ingress/s3-assets/` 전체
- `layers/03-platform/s3-assets/` 전체
- `layers/02-ingress/templates/config.alloy.tftpl`
- `layers/02-ingress/templates/docker-compose.nat-ingress.yaml`
- `layers/02-ingress/templates/nginx.conf.tftpl`
- `layers/04-apps-gateway/templates/config.alloy.tftpl`
- `layers/04-apps-gateway/templates/docker-compose.gateway.yaml.tftpl`
- `layers/05-apps-microservices/templates/config.alloy.tftpl`
- `layers/05-apps-microservices/templates/docker-compose.microservice-*.yaml.tftpl`

### sync.sh 동작 방식
각 레이어의 인스턴스는 `/etc/infra-asset-config`에서 `S3_BUCKET`, `S3_PATH_PREFIX` 등을 읽어 동작합니다. systemd 타이머(5분 주기)가 `/usr/local/bin/sync.sh`를 실행하며, 각 단계는 다음과 같습니다.

- Step 0: sync.sh 자기 자신을 S3에서 내려받아 diff 비교 후 변경 시 exec로 재실행
- Step 1: AWS Secrets Manager에서 시크릿 조회 후 `/home/ec2-user/.env` 및 `/etc/sysconfig/alloy`에 기록
- Step 2~N: S3에서 docker-compose.yaml, config.alloy, nginx.conf 등을 내려받아 현재 파일과 diff 비교
- 변경 감지 시에만 `docker compose up -d` 또는 `systemctl restart alloy` 실행

변경 감지는 diff 비교로 수행하므로 내용이 같으면 서비스 재시작이 발생하지 않습니다.

### 레이어별 secrets 구성

| 레이어 | secrets |
|--------|---------|
| ingress | GRAFANA_API_KEY |
| controlplane | DB_PASSWORD, GRAFANA_API_KEY |
| gateway | GRAFANA_API_KEY |
| microservices | DB_PASSWORD, GRAFANA_API_KEY |

## 4. 보안 그룹 및 IAM 수정 (01-base)

### 보안 그룹
- api_gateway_sg: 인바운드 포트 오류 수정 (from_port=80 → 8080)
- microservices_sg: VPC 전체 허용(`protocol="-1"`) 인바운드 규칙 제거

### IAM
- `secretsmanager:ListSecrets` (Resource: *) 및 `secretsmanager:DescribeSecret` 제거
- `secretsmanager:GetSecretValue`만 특정 secret ARN에 한해 허용
- secrets.tf: db_password, grafana_api_key에서 태그 기반 탐색용 태그 제거

## 5. Grafana Alloy Docker 로그 수집 수정

모든 레이어의 `config.alloy`에서 Docker 컨테이너 로그의 `service_name` 레이블이 올바르게 설정되지 않는 문제를 수정했습니다.

### 원인
`loki.source.docker`가 로그 엔트리를 포워드할 때 `__meta_docker_*` 레이블을 함께 전달하지 않습니다. 기존 `loki.relabel`에서 `__meta_docker_container_name`을 참조하면 항상 빈 값이 되어 Grafana Cloud가 `job` 값을 `service_name`으로 대신 사용합니다.

### 수정 내용
`loki.relabel "docker"` 블록을 제거하고 `discovery.relabel "docker"`로 교체했습니다. discovery 단계에서 `__` 없는 레이블로 변환된 값은 `loki.source.docker`가 로그 엔트리에 그대로 첨부합니다.

```
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

### Grafana 레이블 구조
- `job="quietchatter/docker"` - Docker 컨테이너 로그
- `job="quietchatter/system"` - journald 시스템 로그
- `service_name` - 컨테이너 이름 (예: nginx, api-gateway)
- `instance` - 인스턴스 식별자 (ingress/controlplane은 고정값, gateway/microservices는 sys.env("INSTANCE_NAME"))

## 6. user_data 수정 (gateway, microservices)

gateway(04), microservices(05) user_data에서 불필요한 `mkdir -p /data/app` 제거. EBS 볼륨 마운트 및 /data 경로는 controlplane(03)에만 존재합니다.

## 7. sync.sh 파일 소유권 수정

root가 생성한 파일을 ec2-user가 덮어쓰지 못하는 Permission denied 문제 수정. `/home/ec2-user/` 경로에 파일을 쓴 후 `chown ec2-user:ec2-user`를 실행하도록 ingress, gateway, microservices sync.sh에 추가했습니다.

## 8. 미완료 작업 (다음 세션으로 이월)

- sync.sh 위치를 `/usr/local/bin/sync.sh`에서 `/home/ec2-user/sync.sh`로 변경 필요. SSM 접속 시 ec2-user 홈 경로에서 바로 찾을 수 있어 장애 대응에 유리합니다. systemd 서비스 파일의 ExecStart 경로도 함께 수정해야 합니다.
