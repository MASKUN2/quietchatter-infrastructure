# AI Agent Guide - Infrastructure Module

이 문서는 AI 에이전트가 QuietChatter 프로젝트의 인프라 모듈을 이해하고 관리하기 위한 지침입니다.

## 1. 모듈 개요

* 역할: AWS 리소스 정의 (IaC) 및 각 노드의 설정 (Docker Compose) 관리
* 주요 기술: Terraform 1.7+, Docker, Docker Compose
* 하드웨어: AWS t4g (ARM64) 인스턴스 전용

## 2. 아키텍처 원칙

### A. 비용 최적화
* 최소 사양 인스턴스 사용 (t4g.nano -> NAT, t4g.micro -> App, t4g.small -> DB/Kafka)
* 모든 Java 애플리케이션은 SerialGC와 고정된 힙 메모리 설정을 사용합니다.
* 모든 노드에 2GB 스왑 메모리를 설정하여 OOM을 방지합니다.

### B. 네트워크 및 보안
* 모든 프라이빗 노드는 NAT 인스턴스를 통해 외부와 통신합니다.
* SSH(22포트)를 사용하지 않고 AWS SSM Session Manager를 통해 접속합니다.
* 보안 그룹은 최소 권한 원칙에 따라 열어야 합니다.

### C. 서비스 통신 (Consul)
* 모든 애플리케이션 노드는 로컬 Consul 클라이언트 에이전트를 가집니다.
* 마이크로서비스는 localhost가 아닌 consul-agent 컨테이너 호스트를 통해 통신하거나, network_mode: host 환경에서 작동해야 합니다.

## 3. 에이전트 작업 지침

### 0. 문서 참조 규칙 (필수)
- 작업 시작 전 반드시 docs/ 디렉토리의 모든 문서(업데이트 로그, 아키텍처 전략, 로드맵 등)를 읽고 현재 인프라의 상태와 과거 변경 이력을 파악하십시오. 특히 최근 업데이트 로그(update-log-YYYYMMDD.md)를 통해 최신 변경 사항과 트러블슈팅 이력을 확인하는 것이 가장 중요합니다.

### A. 테라폼 코드 작성 및 실행 규칙
- 계층 준수: 작업 목적에 맞는 적절한 레이어(01-base ~ 05-apps-microservices) 디렉토리에서 작업을 수행하십시오.
- 리소스 참조: 다른 계층의 리소스가 필요한 경우 반드시 data.terraform_remote_state를 사용하십시오.
- 실행 순서: 인프라 전체 재구축 시 README.md에 명시된 01~05 순서를 엄격히 준수하십시오.
- 리소스 명명 규칙: quietchatter-[resource-name] 형식을 따릅니다.
- 하드코딩 금지: 가능한 변수(variables.tf)를 활용하십시오.
- 인스턴스 교체 주의: DB 노드 등 데이터가 포함된 노드는 terraform apply 시 교체되지 않도록 lifecycle 설정을 확인하십시오.

### B. 문서 및 소통 규칙
* 마크다운 작성 시 굵게(bold)나 기울임(italics) 같은 강조 서식을 사용하지 않습니다.
* 마크다운 작성 시 이모티콘을 사용하지 않습니다.

## 4. 검증 지침

* 테라폼 변경 후 반드시 terraform validate 명령을 실행하십시오.
* 새로운 노드 추가 시 반드시 스왑 메모리 설정과 SSM 에이전트 설치 로직을 포함하십시오.

## 5. 주요 트러블슈팅 및 교훈 (Lessons Learned)

### A. NAT 인스턴스 설정 규칙
* 문제: Amazon Linux 2023에서 네트워크 인터페이스 이름(예: eth0, ens5)이 고정되어 있지 않아 iptables 규칙이 깨지는 경우가 발생함.
* 해결: 특정 인터페이스 이름 대신 VPC CIDR 대역을 기준으로 마스커레이딩을 적용합니다.
  (예: iptables -t nat -A POSTROUTING -s ${var.vpc_cidr} -j MASQUERADE)

### B. User Data 내 Nginx/Bash 변수 충돌
* 문제: User Data(Bash) 내에서 cat <<EOT를 사용할 때, Nginx 변수($$host 등)를 Bash 변수로 오해하여 빈 값으로 치환해버리는 문제가 발생함.
* 해결: 반드시 cat <<'EOT' (따옴표 포함) 형식을 사용하여 Bash의 변수 해석을 차단하십시오.
* 주의: 테라폼 템플릿($${...})과 Nginx 변수($$host)를 혼용할 때는 테라폼 templatefile 함수에서 이중 달러 기호($$$$) 처리가 필요할 수 있으므로 최종 생성된 파일을 반드시 점검하십시오.

### C. SSM 접속 및 홈 디렉토리 호환성
* 문제: 서버마다 기본 유저명(/home/ec2-user vs /home/ubuntu)이 달라 SSM Session Manager 접속 프로필의 고정 경로가 오류를 유발함.
* 해결: AWS SSM Preferences의 Shell Profile에서 cd $HOME 명령어를 사용하여 OS 독립적인 홈 이동 방식을 권장합니다.

### D. 템플릿 파일 내 특수 문자($1 등) 이스케이프 주의
* 문제: Alloy 설정이나 Regex 설정에서 $1과 같은 문자를 사용할 때, 테라폼 템플릿에서 이를 $$1로 이스케이프하면 최종 파일에 $1이 아닌 $$1이 그대로 남는 경우가 발생함.
* 원인: User Data에서 cat <<'EOF' (따옴표 포함) 방식을 사용하여 설정 파일을 생성할 경우, Bash는 변수 해석을 시도하지 않으므로 테라폼이 치환한 결과가 그대로 파일에 쓰여짐. 이때 테라폼 템플릿에서 과도하게 이스케이프된 $$1은 그대로 $$1로 저장됨.
* 해결: 테라폼 templatefile 내에서 ${...}와 같이 테라폼 변수로 해석될 위험이 없는 문자열(예: 단순 $1)은 중복 이스케이프($$)를 하지 않고 단일 $를 사용하십시오. 최종적으로 생성된 인스턴스 내의 설정 파일(/etc/alloy/config.alloy 등)에서 $1이 정확히 찍혔는지 반드시 확인하십시오.
