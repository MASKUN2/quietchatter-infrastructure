---
name: grafana-alloy-docker-labels
description: Use when configuring Grafana Alloy to collect Docker container logs, or when service_name and other container metadata labels are empty or missing in Loki
---

# Grafana Alloy Docker Container Labels

## Overview

`loki.source.docker`는 로그 엔트리를 포워드할 때 `__meta_*` 레이블을 전달하지 않는다. 따라서 `loki.relabel`에서 `__meta_docker_container_name`을 참조하면 항상 빈 값이 된다. `discovery.relabel`에서 타겟 단계에 레이블을 설정해야 한다.

## Core Pattern

```hcl
# Wrong: loki.relabel에서 __meta_* 참조 - 항상 빈 값
loki.source.docker "logs" {
  targets = discovery.docker.linux.targets
  ...
}
loki.relabel "add_labels" {
  rule {
    source_labels = ["__meta_docker_container_name"]  // 빈 값
    target_label  = "service_name"
  }
}

# Correct: discovery.relabel에서 타겟 단계에 레이블 설정
discovery.relabel "docker" {
  targets = discovery.docker.linux.targets
  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    replacement   = "$1"
    target_label  = "service_name"
  }
}
loki.source.docker "logs" {
  targets = discovery.relabel.docker.output  // __없는 레이블이 로그 엔트리에 첨부됨
  ...
}
```

## Why

`loki.source.docker`의 `targets`에 `discovery.relabel.*.output`을 넘기면, `__` 접두사가 없는 레이블(service_name 등)은 로그 엔트리에 그대로 첨부된다. `__meta_*`는 타겟 단계에서만 유효하며 로그 엔트리에는 전파되지 않는다.
