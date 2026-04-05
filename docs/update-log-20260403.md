# Infrastructure Update Log (2026-04-03)

이 문서는 2026년 4월 3일 진행된 인프라 코드 보완 및 최적화 작업 내용을 기록합니다.

## 1. 작업 개요
설계 문서(Architecture Strategy)와 실제 구현 코드 간의 차이를 분석하여 누락된 설정을 보완하고, 불필요한 레거시 리소스를 정리하였습니다.

## 2. 주요 변경 사항

### 2.1 API Gateway (Application Node) 구성 완료
- 템플릿 도입: templates/docker-compose.application.yaml.tftpl을 생성하여 Spring Cloud Gateway 실행 구조 마련.
- JVM 튜닝 적용: 전략 문서의 가이드라인에 따라 -Xms256m -Xmx256m 등의 옵션을 환경 변수로 주입.
- 프로비저닝 보완: api_gateway.tf의 User Data 스크립트를 완성하여 인스턴스 부팅 시 Docker Compose 설정이 자동 생성되도록 개선.

### 2.2 NGINX Ingress 프록시 설정 자동화
- 동적 설정: templates/nginx.conf.tftpl 템플릿을 생성하여 API Gateway의 프라이빗 IP를 자동으로 인식하도록 설정.
- 트래픽 라우팅: 외부 80 포트 요청을 내부 API Gateway(8080)로 전달하는 역방향 프록시(Reverse Proxy) 구성.
- Consul UI 노출: 내부 점검을 위해 /consul/ 경로를 통해 Control Plane의 Consul UI에 접근 가능하도록 경로 추가.

### 2.3 리소스 정리 및 최적화
- 불필요 리소스 제거: 기존 Management 노드용 보안 그룹 및 미사용 Docker Compose 템플릿 삭제.
- 의존성(Dependency) 강화: NAT 인스턴스가 준비된 후 다른 노드들이 패키지를 설치할 수 있도록 depends_on 설정을 보완하여 배포 안정성 향상.

### 2.4 운영 편의성 및 설계 일관성 확보
- Control Plane 고정 IP 할당: controlplane 인스턴스에 10.0.101.100 사설 IP를 고정 할당하여 가이드 문서(deployment-roadmap.md) 및 서비스 탐색(Consul) 설정의 일관성을 확보함.
- 이미지 변수화: api_gateway_image` 변수를 도입하여 테라폼 실행 시 애플리케이션 버전을 유연하게 교체할 수 있도록 개선함.
- 레거시 정리: variables.tf 내에 남아있던 management_private_ip 변수를 controlplane_private_ip로 이름 변경 및 역할 재정의함.

## 3. 향후 과제
- SSL/TLS 적용: 현재 80(HTTP)만 열려 있으므로, 실제 운영 환경을 위해 Certbot 등을 통한 443(HTTPS) 인증서 적용 필요.
- 이미지 배포: api-gateway 등 실제 애플리케이션 Docker 이미지를 빌드하여 레지스트리에 푸시하고 배포 확인 필요.
