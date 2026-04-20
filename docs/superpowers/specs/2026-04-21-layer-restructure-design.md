---
title: Terraform 레이어 구조 간소화
date: 2026-04-21
status: approved
---

# Terraform 레이어 구조 간소화

## 배경

기존 6개 레이어(01-base, 02-ingress, 03-platform, 04-apps-gateway, 05-apps-microservices, 06-apps-frontend)는
초기 학습 목적으로 과도하게 세분화된 구조였다. 실제 운영에서 레이어를 독립적으로 apply하는 일이 없었고,
remote_state 의존성 체인이 불필요하게 길었다.

## 결정 사항

### 레이어 구조 변경

기존 6레이어를 3레이어로 통합한다.

```
01-base     → VPC, IAM, S3, Secrets, Security Groups, NAT 노드 (변경 없음)
02-platform → Controlplane 노드 (03-platform에서 번호 변경)
03-apps     → Gateway 노드 + Microservices 노드 + Frontend 노드 통합
              (04-apps-gateway + 05-apps-microservices + 06-apps-frontend 통합)
```

삭제 대상: 02-ingress 레이어 (Ingress 노드 제거)

### Ingress 노드 제거 및 Gateway 노드 재설계

기존 02-ingress 레이어의 NGINX 노드(t4g.micro)는 단순 리버스 프록시만 수행하고 있었다.
이를 Gateway 노드 내부로 이전하여 별도 인스턴스를 제거한다.

Gateway 노드 구성:
- 서브넷: 퍼블릭
- IP: EIP 고정 (단일 EC2, ASG 없음)
- NGINX: 80/443 포트 수신, SSL 처리(Let's Encrypt), localhost:8080으로 프록시
- Spring Cloud Gateway: localhost:8080 바인딩, JWT 검증 및 내부 라우팅

트래픽 흐름:
```
Internet → NGINX(80/443, EIP) → Spring Cloud Gateway(localhost:8080) → Private subnet
```

### ALB 미사용 결정

비용 절감 목적으로 ALB를 사용하지 않는다.
진입점은 단일 EC2 + EIP로 관리하며, SSL은 Gateway 노드의 NGINX에서 Let's Encrypt로 처리한다.

## 노드 구성 (변경 후)

| 노드 | 타입 | 서브넷 | 역할 |
|------|------|--------|------|
| NAT | t4g.nano | 퍼블릭 | 프라이빗 서브넷 아웃바운드 라우팅 |
| Controlplane | t4g.small | 프라이빗 | Postgres, Redis, Kafka, Consul |
| Gateway | t4g.micro | 퍼블릭 | NGINX + Spring Cloud Gateway, EIP |
| Microservices | t4g.micro | 프라이빗 | 각 마이크로서비스 |
| Frontend | t4g.micro | 프라이빗 | Next.js BFF, Consul 에이전트 |

## 구현 범위

1. 02-ingress 레이어 디렉토리 삭제
2. 03-platform → 02-platform으로 이동 및 data.tf remote_state 참조 경로 수정
3. 04-apps-gateway, 05-apps-microservices, 06-apps-frontend → 03-apps로 통합
4. 03-apps/gateway.tf: Gateway 노드를 퍼블릭 서브넷으로 이동, EIP 연결, NGINX 동거 설정 추가
5. 03-apps/microservices.tf, 03-apps/frontend.tf: 기존 내용 유지, remote_state 참조 경로만 수정
6. 01-base 보안 그룹: Gateway 노드용 인바운드 80/443 허용 규칙 추가

## 제외 범위

- 각 노드의 S3 sync 방식, docker-compose, Grafana Alloy 설정은 변경하지 않는다.
- 기존 Consul DNS 연동 구조는 그대로 유지한다.
