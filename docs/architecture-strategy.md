# Infrastructure Architecture & Strategy

이 문서는 QuietChatter 프로젝트의 인프라 구축 전략과 비용 최적화 설계 방안을 기술합니다.

## 1. 아키텍처 개요
본 인프라는 AWS 환경에서 최소한의 비용으로 마이크로서비스를 안정적으로 운영하기 위해 3노드 통합 구조를 채택합니다.

## 2. 노드 구성 전략 (Unified 3-Node Architecture)

| 노드 그룹 | 인스턴스 사양 | 주요 서비스 | 비고 |
| :--- | :--- | :--- | :--- |
| NAT / Ingress | t4g.nano (0.5GB) | NAT, NGINX | 외부 게이트웨이 및 라우팅 |
| controlplane | t4g.small (2.0GB) | Postgres, Redis, Kafka, Consul | 시스템 상태 및 데이터 관리 핵심부 |
| Application | t4g.micro (1.0GB) | Spring Cloud Gateway, 마이크로서비스 | 서비스 로직 실행부 |

## 3. 핵심 기술 및 비용 최적화 전략
- 통합 컨트롤 플레인: 관리 서비스(Consul Server)와 데이터 저장소를 하나의 노드에 통합하여 인스턴스 유지 비용 최소화.
- Consul 에이전트 기반 통신: 각 애플리케이션 노드에 경량 Consul 클라이언트 에이전트를 배치하여 서비스 검색의 안정성과 로컬 헬스 체크 성능을 확보하여 JVM 메모리 낭비 제거.
- JVM 메모리 튜닝: AOT 대신 엄격한 JVM 옵션 관리를 통해 t4g.micro 사양에서 스프링 부트 운영.
- 안정성 강화: 모든 노드에 2GB 스왑 메모리 설정으로 메모리 부족(OOM) 방어.
- 보안 강화: 22번 포트 차단 및 AWS SSM Session Manager를 통한 무키(Keyless) 접속 환경 구축.

## 4. JVM 튜닝 가이드라인 (t4g.micro 대응)
- Heap Memory: -Xms256m -Xmx256m (고정 및 최소화)
- Metaspace: -XX:MaxMetaspaceSize=128m
- GC: -XX:+UseSerialGC (싱글 스레드 기반 경량 GC)
- Thread Stack: -Xss256k
- Docker Limit: 컨테이너 메모리 제한 450M 권장

## 5. 예상 비용 (서울 리전 기준)
- 월 총합: 약 $32.00 (한화 약 4만 5천 원 수준)
- 초기 설계 대비 약 58% 비용 절감 달성.

## 6. Infrastructure as Code (IaC) 작성 및 트러블슈팅 가이드

### 6.1 Terraform과 Shell/Nginx 변수 충돌 방지
테라폼의 `${}` 보간(Interpolation)과 쉘/Nginx의 `$` 변수 문법이 충돌할 때 발생하는 문제를 방지하기 위한 표준입니다.

- **Quoted Here-Doc 사용**: User Data에서 설정 파일을 생성할 때 반드시 `cat <<'EOF'`와 같이 `EOF`를 따옴표로 감싸야 합니다. 따옴표가 없으면 쉘이 Nginx의 `$remote_addr` 등을 환경 변수로 오해하여 빈 값으로 치환해 버리는 현상이 발생합니다.
- **Terraform 보간과 리터럴 구분**: 테라폼은 `${}` 형태만 치환합니다. Nginx 설정에서 `$host`처럼 중괄호가 없는 경우는 테라폼이 무시하므로 안전합니다. 만약 쉘 스크립트 내에서 테라폼 변수를 써야 한다면 템플릿 파일에서 명시적으로 `${variable}`을 사용하십시오.

### 6.2 Docker 권한 관리 (Alloy/Agent)
- **Problem**: Grafana Alloy와 같이 호스트의 Docker 소켓(`/var/run/docker.sock`)을 사용하는 에이전트가 `permission denied`로 실행되지 않는 문제가 발생할 수 있습니다.
- **Solution**: 시스템 패키지로 설치된 에이전트 사용자(예: `alloy`)를 반드시 `docker` 그룹에 추가해야 합니다.
  ```bash
  dnf install alloy -y
  usermod -aG docker alloy
  systemctl restart alloy
  ```

### 6.3 변수 처리 표준화
- **Unused Variables**: 사용하지 않는 변수는 `templatefile` 호출 시점에서 즉시 제거하여 코드의 명확성을 유지하십시오. (예: `nginx.conf`에서 사용되지 않는 `controlplane_ip` 제거 완료)
- **Secret Injection**: 보안을 위해 모든 민감 정보는 `01-base` 레이어의 AWS Secrets Manager에 등록하고, 각 노드의 `user_data`에서 부팅 시 `aws secretsmanager get-secret-value`를 통해 조회하여 환경 변수로 주입합니다.
