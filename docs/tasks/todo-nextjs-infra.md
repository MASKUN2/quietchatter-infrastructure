# Next.js 인프라 배치 TODO

## 검증 후 적용 필요 항목

### 적용 순서

1. 01-base apply: frontend SG 생성, api_gateway SG에 frontend 허용 추가 (nat_ingress 허용은 유지)
2. 06-apps-frontend apply: Next.js BFF EC2 기동
3. Next.js 컨테이너 기동 확인
4. 02-network-services apply: Nginx upstream을 Next.js BFF로 전환 (NAT 인스턴스 교체, 2-3분 다운타임)
5. 01-base re-apply (선택): api_gateway SG에서 nat_ingress 허용 제거 (보안 강화, 트래픽이 완전히 BFF를 통하도록 확정 후)

### 01-base 레이어

```bash
cd infrastructure/layers/01-base
terraform apply
```

예상 변경 사항:
- aws_security_group.frontend 생성
- aws_security_group.api_gateway ingress 추가 (frontend SG 허용)
- aws_secretsmanager_secret.bff_jwt_secret_key 생성
- aws_iam_role_policy.secrets_policy 업데이트 (bff_jwt_secret_key ARN 추가)

### 06-apps-frontend 레이어

01-base apply 완료 후 실행한다.

```bash
cd infrastructure/layers/06-apps-frontend
terraform init
terraform apply
```

### 02-network-services 레이어

06-apps-frontend apply 완료 후 Next.js 컨테이너 기동을 확인한 뒤 실행한다.
NAT 인스턴스가 교체되므로 2-3분간 서비스 중단이 발생한다.

```bash
cd infrastructure/layers/02-network-services
terraform apply
```

### 01-base 재적용 (선택 사항)

02-network-services apply 완료 후 트래픽이 정상적으로 Next.js BFF를 통해 API Gateway로 전달되는 것을
확인한 뒤, api_gateway SG에서 nat_ingress 허용을 제거하여 보안을 강화할 수 있다.

security.tf의 api_gateway SG ingress에서 nat_ingress 블록을 제거하고 다시 apply한다.
