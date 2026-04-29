---
name: grafana-alloy-k8s-logs
description: Use when configuring Grafana Alloy DaemonSet to collect Kubernetes pod logs, or when service_name and pod metadata labels are empty or missing in Loki
---

# Grafana Alloy Kubernetes Pod Log Collection

## Overview

Alloy는 k8s DaemonSet으로 각 노드에서 실행되며, Kubernetes API를 통해 파드 로그를 수집한다. `discovery.kubernetes`로 파드를 탐색하고, `loki.source.kubernetes`로 로그를 수집한다.

## Core Pattern

```hcl
// 파드 탐색
discovery.kubernetes "pods" {
  role = "pod"
}

// 레이블 정제 (필요한 메타데이터만 유지)
discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label  = "service_name"
  }
}

// 로그 수집
loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.write.grafana_cloud.receiver]
}
```

## Why

`__meta_kubernetes_*` 레이블은 `discovery.relabel`의 타겟 단계에서만 유효하다. `loki.source.kubernetes`의 targets에 `discovery.relabel.*.output`을 넘기면 `__` 접두사가 없는 레이블(namespace, pod, service_name 등)이 로그 엔트리에 첨부된다.

## 주의사항

- Alloy DaemonSet에는 파드 로그 접근을 위한 ClusterRole이 필요하다 (get, list, watch on pods, pods/log)
- 노드별로 해당 노드의 파드 로그만 수집하므로 DaemonSet 배포가 필수
