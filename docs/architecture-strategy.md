# Infrastructure Architecture & Strategy

이 문서는 QuietChatter 프로젝트의 인프라 구축 전략과 비용 최적화 설계 방안을 기술합니다.
**참고**: AI 에이전트라면 작업 전 반드시 루트의 **AGENTS.md**를 먼저 읽으십시오.

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
