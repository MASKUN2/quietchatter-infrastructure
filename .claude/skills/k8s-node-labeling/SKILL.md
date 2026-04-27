---
name: k8s-node-labeling
description: Use when configuring or troubleshooting k8s node labels, nodeSelector, or ROLES column display in QuietChatter k3s cluster
---

# k8s 노드 라벨링 지침

## 라벨 구조

노드 라벨은 키-값 쌍이다. QuietChatter는 역할 구분에 커스텀 접두사를 사용한다.

```
키:   quietchatter.io/role
값:   controlplane | platform | gateway | worker
```

## 설정 위치

### 1. user_data 템플릿 (k3s 설치 시 부여)

kubelet은 보안 정책상 `kubernetes.io/*` 네임스페이스 라벨을 `--node-label`로 설정하는 것을 금지한다 (k8s 1.24+). 커스텀 접두사만 허용된다.

```bash
# 올바른 형식
--node-label="quietchatter.io/role=worker"

# 금지 - kubelet이 거부함
--node-label="node-role.kubernetes.io/worker=true"
```

### 2. 매니페스트 nodeSelector (파드 배치)

```yaml
nodeSelector:
  quietchatter.io/role: worker
```

### 3. ROLES 컬럼 표시 (sync.sh에서 부여)

`kubectl get nodes`의 ROLES 컬럼은 `node-role.kubernetes.io/<role>` 키를 가진 라벨만 읽는다. 이 라벨은 kubelet이 직접 설정할 수 없으므로 controlplane의 sync.sh에서 kubectl로 부여한다.

```bash
for role in controlplane platform gateway worker; do
  kubectl label node -l quietchatter.io/role=$role \
    node-role.kubernetes.io/$role=true --overwrite 2>/dev/null || true
done
```

sync.sh가 5분마다 실행되므로 새 노드 합류 후 최대 5분 내에 ROLES가 자동으로 표시된다.

## 노드별 역할 정리

| 노드 | quietchatter.io/role | 주요 워크로드 |
|---|---|---|
| controlplane | controlplane | k3s server, Redis |
| platform | platform | Redpanda |
| gateway | gateway | NGINX, API Gateway |
| worker (ASG) | worker | member, book, talk |
