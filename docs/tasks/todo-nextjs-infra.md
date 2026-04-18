# Next.js 인프라 배치 TODO

## 검증 후 적용 필요 항목

### 01-base 레이어

terraform plan 결과 확인 후 아래 명령을 실행한다.

주의: api_gateway SG 인바운드 규칙이 nat_ingress -> frontend로 변경되므로,
06-apps-frontend 레이어가 apply되어 frontend EC2가 실행 중인 상태에서 적용해야 한다.

```bash
cd infrastructure/layers/01-base
terraform apply
```

예상 변경 사항:
- aws_security_group.frontend 생성
- aws_security_group.api_gateway ingress 규칙 변경
- aws_secretsmanager_secret.bff_jwt_secret_key 생성

### 06-apps-frontend 레이어

01-base apply 완료 후 실행한다.

```bash
cd infrastructure/layers/06-apps-frontend
terraform init
terraform apply
```

### 02-network-services 레이어

06-apps-frontend apply 완료 후 Next.js 컨테이너가 기동된 것을 확인한 뒤 실행한다.
NAT 인스턴스가 교체되므로 2-3분간 서비스 중단이 발생한다.

```bash
cd infrastructure/layers/02-network-services
terraform apply
```

## 적용 순서 요약

1. terraform apply 01-base
2. terraform apply 06-apps-frontend
3. Next.js 컨테이너 기동 확인
4. terraform apply 02-network-services
