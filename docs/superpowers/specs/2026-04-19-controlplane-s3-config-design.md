# 컨트롤플레인 설정 관리 S3 분리 설계

## 목표

현재 Terraform user_data 템플릿에 인라인으로 삽입되는 docker-compose.yaml과 config.alloy를
S3 기반으로 분리한다. 설정 파일 변경 시 인스턴스 교체 없이 반영 가능한 구조를 만드는 것이 목적이다.

## 역할 분리 원칙

user_data: 인프라 수준의 1회성 부팅 작업만 담당한다.
S3: 운영 중 변경 가능한 모든 설정 파일과 스크립트를 관리한다.

## S3 버킷 구조

```
s3://quietchatter-controlplane-config/controlplane/
  config/
    docker-compose.yaml
    config.alloy
  scripts/
    sync.sh
```

## user_data 역할 (최소화)

1. 인터넷 연결 확인 (NAT 인스턴스 대기)
2. Swap 파일 생성 및 마운트
3. EBS 볼륨 마운트 (/data)
4. Docker 및 Docker Compose 설치
5. Grafana Alloy 패키지 설치
6. init-db.sql 생성 (최초 1회, DB 스키마 초기화)
7. S3에서 sync.sh pull
8. sync.sh 최초 실행 (부팅 시 초기 설정)
9. systemd timer 등록 (이후 주기적 실행)

## sync.sh 역할

systemd timer에 의해 5분마다 실행된다. 부팅 시에도 1회 실행된다.

### 시크릿 동기화

Secrets Manager에서 태그 `controlplane=true`가 붙은 시크릿을 전부 조회한다.
시크릿 이름을 키로, 값을 value로 하여 /data/app/.env와 /etc/sysconfig/alloy에 기록한다.
변경이 있으면 docker compose up -d 및 systemctl restart alloy를 실행한다.

### 설정 파일 동기화

S3에서 docker-compose.yaml을 pull하여 현재 파일과 diff한다.
변경이 있으면 파일을 교체하고 docker compose up -d를 실행한다.

S3에서 config.alloy를 pull하여 현재 파일과 diff한다.
변경이 있으면 파일을 교체하고 systemctl restart alloy를 실행한다.

변경이 없으면 서비스 재시작 없이 종료한다.

## systemd 구성

controlplane-config-sync.service: sync.sh를 실행하는 one-shot 서비스
controlplane-config-sync.timer: 5분 간격으로 service를 트리거

## 시크릿 태깅 규칙

컨트롤플레인에서 사용하는 모든 Secrets Manager 시크릿에 태그를 붙인다.

```
Tag Key: controlplane
Tag Value: true
```

현재 대상 시크릿:
- DB_PASSWORD
- GRAFANA_API_KEY

새 시크릿 추가 시: AWS에서 시크릿 생성 후 위 태그만 붙이면 다음 sync.sh 실행 시 자동 반영된다.
Terraform 또는 user_data 수정 불필요.

## config.alloy 처리

loki_url과 loki_user는 민감 정보가 아니므로 config.alloy 파일에 직접 기재한다.
GRAFANA_API_KEY는 sys.env("GRAFANA_API_KEY")로 참조한다 (Secrets Manager에서 주입).

## Terraform 변경 범위

### 03-platform

추가:
- aws_s3_bucket.controlplane_config
- aws_s3_bucket_public_access_block.controlplane_config

변경:
- controlplane.tf: templatefile 인자에서 alloy_config, docker_compose_config 제거.
  s3_bucket_name, loki_url, loki_user, instance_name 추가.
- user_data.sh.tftpl: 설정 파일 인라인 삽입 제거. S3 pull + sync.sh 실행 + systemd timer 등록으로 교체.

삭제:
- docker-compose.controlplane.yaml.tftpl (Terraform 관리 해제)
- variables.tf의 미사용 api_gateway_image 변수 제거

### 01-base

변경:
- IAM 인스턴스 프로파일 정책에 S3 권한 추가
  (s3:GetObject, s3:ListBucket - 해당 버킷만)

## 운영 절차

설정 파일 변경 시:
```
aws s3 cp docker-compose.yaml s3://quietchatter-controlplane-config/controlplane/config/docker-compose.yaml
```
최대 5분 내에 인스턴스가 자동으로 반영한다.

즉시 반영이 필요한 경우 SSM Run Command로 sync.sh를 직접 실행한다.

## 적용 레이어 순서

1. terraform apply (01-base) - IAM 정책 업데이트
2. aws s3 cp로 config/, scripts/ 파일 업로드
3. terraform apply (03-platform) - 인스턴스 교체 발생 (마지막 1회)
