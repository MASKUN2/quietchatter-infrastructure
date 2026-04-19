# Frontend Consul DNS 연동 태스크

## 목표

현재 Next.js BFF(frontend)는 두 가지 문제가 있다.

1. API Gateway를 고정 IP(10.0.101.200)로 호출하고 있다.
2. Consul agent가 실행되지만 frontend 서비스가 Consul에 등록되지 않는다.

이 태스크는 다음 두 가지를 구현한다.

1. frontend 서비스를 Consul에 등록한다.
2. API Gateway 호출을 고정 IP 대신 Consul DNS(api-gateway.service.consul)로 변경한다.

---

## 작업 전 필독

- AGENTS.md: 아키텍처 원칙 및 작업 규정
- docs/update-log-*.md: 최신 인프라 상태 파악

---

## 현재 상태 파악

작업 전 다음 파일들을 반드시 읽는다.

- layers/06-apps-frontend/templates/docker-compose.frontend.yaml.tftpl
- layers/06-apps-frontend/templates/user_data.sh.tftpl
- layers/06-apps-frontend/frontend.tf
- layers/01-base/security.tf (frontend SG 관련 규칙 확인)

---

## 구현 지침

### 1. Consul 서비스 등록 설정 추가

Consul에 서비스를 등록하는 방법은 두 가지이다.

방법 A (권장): docker-compose에서 consul-agent 실행 시 서비스 정의 파일을 함께 마운트한다.

layers/06-apps-frontend/templates/docker-compose.frontend.yaml.tftpl 의 consul-agent 서비스를 다음과 같이 수정한다.

```yaml
  consul-agent:
    image: hashicorp/consul:1.14
    container_name: quietchatter-consul-agent
    restart: always
    environment:
      CONSUL_BIND_INTERFACE: ens5
    command: "agent -join=${controlplane_ip} -data-dir=/consul/data -config-dir=/consul/config -client=0.0.0.0"
    volumes:
      - /home/ec2-user/consul_config:/consul/config
    network_mode: host
    deploy:
      resources:
        limits:
          memory: 100M
```

user_data.sh.tftpl 의 Docker Compose 파일 생성 단계(STEP 5) 이전에 consul_config 디렉토리와 서비스 정의 파일을 생성하는 단계를 추가한다.

```bash
log "STEP 5: Consul 서비스 정의 파일을 생성하고 있습니다..."
{
  mkdir -p /home/ec2-user/consul_config
  cat <<'EOF' > /home/ec2-user/consul_config/frontend.json
{
  "service": {
    "name": "microservice-frontend",
    "port": 3000,
    "check": {
      "http": "http://localhost:3000/health",
      "interval": "10s",
      "timeout": "3s"
    }
  }
}
EOF
} || error_handler "Consul 서비스 정의 파일 생성"
```

서비스 이름은 `microservice-frontend`로 통일한다. 다른 서비스들의 네이밍 패턴(microservice-member, microservice-api-gateway 등)을 따른다.

헬스체크 경로 `/health`는 Next.js 앱에 해당 엔드포인트가 없다면 `tcp` 방식으로 대체한다.

```json
"check": {
  "tcp": "localhost:3000",
  "interval": "10s",
  "timeout": "3s"
}
```

### 2. API Gateway 호출을 Consul DNS로 변경

docker-compose.frontend.yaml.tftpl 에서 INTERNAL_API_GATEWAY_URL 환경변수를 수정한다.

변경 전:
```yaml
- INTERNAL_API_GATEWAY_URL=http://${api_gateway_ip}:8080
```

변경 후:
```yaml
- INTERNAL_API_GATEWAY_URL=http://microservice-api-gateway.service.consul:8080
```

Consul DNS는 기본적으로 localhost:8600에서 동작한다. network_mode: host를 사용하므로 Next.js 컨테이너에서 localhost로 Consul DNS를 조회할 수 있다.

단, Node.js는 시스템 DNS를 사용하므로 Consul DNS 포트(8600)를 표준 DNS 포트(53)로 리다이렉트하거나, resolv.conf에 Consul DNS를 등록해야 한다.

user_data.sh.tftpl 에 다음 설정을 추가한다 (Docker 설치 이후 단계에 삽입).

```bash
log "STEP X: Consul DNS를 시스템 DNS에 등록합니다..."
{
  cat <<'EOF' > /etc/systemd/resolved.conf.d/consul.conf
[Resolve]
DNS=127.0.0.1:8600
Domains=~consul
EOF
  systemctl restart systemd-resolved
} || error_handler "Consul DNS 설정"
```

AL2023은 systemd-resolved를 사용하므로 위 방법이 표준 접근이다.

### 3. frontend.tf 에서 api_gateway_ip 변수 제거

docker-compose 템플릿에서 api_gateway_ip 참조를 제거했으므로, frontend.tf 의 templatefile 호출에서도 해당 변수를 제거한다.

변경 전:
```hcl
  docker_compose_config = templatefile("${path.module}/templates/docker-compose.frontend.yaml.tftpl", {
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.frontend_image
    api_gateway_ip  = data.terraform_remote_state.base.outputs.api_gateway_private_ip
  })
```

변경 후:
```hcl
  docker_compose_config = templatefile("${path.module}/templates/docker-compose.frontend.yaml.tftpl", {
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = var.frontend_image
  })
```

---

## 검증

코드 수정 후 반드시 실행한다.

```bash
cd infrastructure/layers/06-apps-frontend
terraform validate
```

validate 통과 후 plan을 확인한다.

```bash
terraform plan
```

user_data_replace_on_change = true 설정으로 인해 frontend EC2 인스턴스가 교체된다. plan 결과에서 이를 확인한다.

---

## 주의사항

- Consul agent가 controlplane에 join하기 전에 frontend 컨테이너가 먼저 뜨면 DNS 조회에 실패한다. docker-compose depends_on 또는 컨테이너 시작 순서를 고려한다.
- microservice-api-gateway 서비스 이름은 Gateway 서비스의 application.yml에서 `spring.application.name` 또는 Consul 등록 이름을 확인하여 정확히 일치시킨다. layers/04-apps-gateway/templates/docker-compose.gateway.yaml.tftpl 에서 SPRING_APPLICATION_NAME 환경변수를 확인한다.
- AGENTS.md의 Lessons Learned 항목 중 user_data 변수 이스케이프 규칙을 반드시 준수한다.
