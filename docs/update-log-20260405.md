# 인프라 업데이트 로그 - 2026-04-05

## 1. Grafana Alloy Docker 권한 문제 해결
Grafana Alloy가 컨테이너 로그를 수집하기 위해 `/var/run/docker.sock`에 접근할 때 `permission denied` 에러가 발생하는 문제를 해결했습니다.

### 수정 사항
- `layers/02-network-services`, `layers/03-platform`, `layers/04-apps-gateway`의 `user_data.sh.tftpl` 수정.
- `alloy` 설치 직후 `usermod -aG docker alloy` 명령을 실행하여 `alloy` 사용자를 `docker` 그룹에 추가.

### 기존 인스턴스 조치 방법
이미 실행 중인 인스턴스에서는 다음 명령어를 수동으로 실행해야 합니다.
```bash
sudo usermod -aG docker alloy
sudo systemctl restart alloy
```

## 2. Nginx 설정 및 변수 처리 검증
`layers/02-network-services`의 Nginx 설정(`nginx.conf.tftpl`)이 올바르게 변수를 처리하고 있는지 확인했습니다.

### 검증 결과
- `upstream api_gateway { server ${api_gateway_ip}:8080; }` 설정이 테라폼 변수(`api_gateway_ip`)를 통해 동적으로 주입되고 있음을 확인.
- 현재 `api_gateway_ip`는 `10.0.101.200`으로 고정 할당되어 운영 중.
- `controlplane_ip` 변수는 Nginx 설정에서 사용되지 않음을 확인하여 `layers/02-network-services/nat_ingress.tf` 템플릿 호출에서 제거 완료.

## 3. Grafana Alloy 컨테이너 로그 레이블링 개선
도커 컨테이너 로그가 그라파나에서 unknown_service로 표시되는 문제를 해결하고, 일관된 서비스 명명을 위한 접두사를 추가했습니다.

### 수정 사항
- layers/02-network-services, layers/03-platform, layers/04-apps-gateway의 config.alloy.tftpl 수정.
- loki.relabel "docker" 섹션에서 __meta_docker_container_name으로부터 컨테이너 이름을 추출하여 service 레이블로 저장하는 규칙 추가.
- 정규표현식 regex="/(.*)"과 replacement="quietchatter-$1"을 사용하여 앞의 슬래시를 제거하고 quietchatter- 접두사를 추가함.
- 시스템 로그(journald)의 작업 이름을 quietchatter/systemd-journal로, 서비스 이름을 system으로 표준화하여 업계 관례를 따름.
- 컨테이너 로그의 작업 이름을 quietchatter/docker-logs로 명명하고, 서비스 이름에 quietchatter- 접두사를 부여하여 일관성을 확보함.
- 모든 레이어에서 job, service, instance 레이블을 계층적으로 구조화하여 그라파나 탐색 편의성을 극대화함.

### 기존 인스턴스 조치 방법
테라폼 apply를 통해 설정을 업데이트하거나, 각 인스턴스의 /etc/alloy/config.alloy 파일을 직접 수정하고 alloy 서비스를 재시작해야 합니다.
service 레이블을 기준으로 로그를 필터링할 수 있습니다.

## 5. Docker 설치 안정화 및 에러 핸들링 개선
Amazon Linux 2023에서 `dnf` 캐시 문제로 Docker 설치가 실패하거나, 설치 실패 후에도 스크립트가 계속 진행되어 발생하는 오류를 해결했습니다.

### 수정 사항
- 모든 레이어(`02-network-services`, `03-platform`, `04-apps-gateway`, `05-apps-microservices`)의 `user_data` 스크립트 수정.
- `set -e`를 추가하여 스크립트 도중 오류 발생 시 즉시 중단되도록 개선.
- Docker 설치 전 `dnf clean all`을 실행하여 패키지 매니저 캐시를 정리.
- `dnf install docker -y` 실패 시 5초 대기 후 재시도하는 로직 추가.

### 기대 효과
- `dnf` 일시적 오류로 인한 Docker 설치 실패 방지.
- Docker가 설치되지 않은 상태에서 `usermod`나 `docker compose` 명령이 실행되는 논리적 오류 차단.
- 인프라 배포의 성공률 및 디버깅 편의성 향상.

## 6. 향후 권한 관리 주의사항
- 신규 서비스 추가 시 Docker 소켓을 사용하는 에이전트(예: Promtail, Alloy, Cadvisor)는 반드시 `docker` 그룹 권한을 부여받아야 함.
- Amazon Linux의 Docker 소켓 기본 권한은 `root:docker (660)` 임을 명심할 것.

## 7. Alloy 로그 라벨링 및 테라폼 치환 오류 해결
도커 컨테이너 로그가 그라파나에서 올바른 컨테이너 이름으로 분류되지 않는 문제를 발견하고, 라벨링 파이프라인 전체를 수정했습니다.

### 문제 원인
1. **문법 오류**: `config.alloy` 템플릿의 `labels` 맵핑에서 마지막 항목 뒤에 콤마(`,`)가 누락되어 Alloy 서비스가 시작되지 못했습니다.
2. **테라폼 치환 변수 증발**: 테라폼의 `templatefile` 함수에서 정규표현식 참조변수인 `$1`을 인식하지 못하고 빈 문자열로 증발시켜버렸습니다.
3. **메타데이터 소실**: `loki.source.docker`는 타겟팅 단계에서만 도커 메타데이터(`__meta_docker_container_name`)를 보유하며, `loki.relabel` 컴포넌트로 전달되기 전에 해당 정보가 소실되었습니다.

### 해결 조치
- 모든 `config.alloy.tftpl`의 맵핑에 콤마를 추가하여 문법 표준을 준수.
- 테라폼 템플릿 내에서 $1이 테라폼 변수로 오해받지 않도록 user_data의 cat <<'EOF' (따옴표 포함) 방식을 활용하여, 템플릿 내에서 단일 $1을 그대로 서버에 전달하도록 수정 (과도한 이스케이프 $$1 제거).
- `discovery.relabel` 컴포넌트를 추가하여, 타겟 단계에서 메타데이터를 `service_name` 영구 라벨로 확정(`promote`)한 뒤 `loki.source.docker`가 이를 수집하도록 개선.
- `instance` 이름을 하드코딩(`nat-ingress` 등)에서 실제 인스턴스 태그(`quietchatter-<서비스>-node`)와 일치하도록 동적 변수 주입 방식으로 변경.

## 8. Docker Compose 컨테이너 이름 명시
`docker stats` 및 그라파나 로그 뷰에서 컨테이너를 명확히 식별하기 위해 모든 Docker Compose 템플릿을 수정했습니다.

### 해결 조치
- 모든 레이어의 `docker-compose*.yaml*` 파일 내 각 서비스에 `container_name: quietchatter-<서비스명>` 속성 명시.
- 도커 엔진이 임의로 생성하는 이름(`ec2-user-ingress-1` 등)을 방지하고 예측 가능한 네이밍 규칙 강제.

## 9. 미사용 테라폼 템플릿 파일 정리
각 레이어(`layers/02` ~ `05`)의 `templates/` 디렉토리에 중복해서 존재하던 미사용 파일들을 삭제하여 저장소 구조를 간결하게 정리했습니다.

### 삭제 대상
- 해당 레이어의 테라폼 코드(`*.tf`)에서 참조하지 않는 모든 `.tftpl` 및 `.yaml` 파일.
- 각 레이어는 이제 자신의 역할(NAT, Platform, Gateway, Microservices)에 꼭 필요한 템플릿 파일만 보유함.
