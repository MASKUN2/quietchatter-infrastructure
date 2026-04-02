# Consul 기반 서비스 탐색 및 설정 전략 (Consul Strategy)

이 문서는 기존의 Spring Cloud Eureka와 Config Server를 대체하여 HashiCorp Consul을 도입하는 인프라 전략을 정의합니다.

## 1. 개요 및 목적

저사양 인프라(t4g.nano/micro) 환경에서 자바 기반의 Eureka와 Config Server 구동에 따른 메모리 낭비를 줄이고, 보다 가볍고 강력한 인프라 관리 기능을 확보하고자 합니다.

## 2. Consul의 역할

* 서비스 디스커버리: 모든 마이크로서비스는 Consul에 등록되며, 게이트웨이는 이를 참조하여 트래픽을 라우팅합니다.
* 설정 관리 (Key-Value Store): 각 서비스의 설정값을 Consul의 KV Store에서 중앙 집중식으로 관리합니다.
* 헬스 체크: 각 인스턴스의 상태를 주기적으로 확인하여 정상적인 노드로만 요청을 보냅니다.

## 3. 인프라 구현 세부사항

* 배포 방식: Consul은 전용 매니지먼트 노드에 바이너리 형태로 설치하거나, Docker 컨테이너로 구동합니다.
* 데이터 저장: 설정 데이터와 서비스 상태 정보의 영속성을 위해 호스트 볼륨 매핑을 사용합니다.
* 보안 그룹: 각 마이크로서비스 노드들이 Consul의 통신 포트(예: 8500, 8300 등)에 접근할 수 있도록 인프라 보안 규칙을 구성해야 합니다.

## 4. 백엔드 연동 지침

* Discovery: spring-cloud-starter-consul-discovery 의존성을 사용합니다.
* Config: spring-cloud-starter-consul-config 의존성을 사용합니다.
* bootstrap.yml 또는 application.yml에서 Consul의 주소와 설정 경로를 정의합니다.
