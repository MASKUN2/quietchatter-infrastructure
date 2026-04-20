---
name: s3-config-sync
description: Use when modifying sync.sh, writing files to /home/ec2-user/ from a root-run script, configuring /etc/sysconfig/alloy, or using mktemp in sync operations on quietchatter EC2 nodes
---

# S3 Config Sync Operations

## Overview

`sync.sh`는 S3에서 docker-compose 및 Alloy 설정을 주기적으로 내려받아 EC2 노드에 적용한다. root 권한으로 실행되므로 파일 소유권, 경로, systemd 환경변수 설정에 반드시 주의가 필요하다.

## Quick Reference

| 상황 | 규칙 |
|---|---|
| /home/ec2-user/ 하위 파일 생성 | 생성 직후 `chown ec2-user:ec2-user` 실행 |
| mktemp 사용 | 기본값 `/tmp/` 사용. `~` 지정 금지 (root 홈인 `/root/`로 해석됨) |
| /etc/sysconfig/alloy 덮어쓰기 | 반드시 `CONFIG_FILE=/etc/alloy/config.alloy` 포함 |
| sync.sh 경로 | 현재 `/usr/local/bin/sync.sh` - SSM 접속 시 ec2-user 홈에서 보이지 않음, `/home/ec2-user/sync.sh`로 이동 예정 |

## Common Mistakes

**파일 소유권 누락**
```bash
# Wrong: root 소유로 생성되어 이후 ec2-user 실행 시 Permission denied
cp /tmp/docker-compose.yml /home/ec2-user/docker-compose.yml

# Correct
cp /tmp/docker-compose.yml /home/ec2-user/docker-compose.yml
chown ec2-user:ec2-user /home/ec2-user/docker-compose.yml
```

**mktemp 경로 오용**
```bash
# Wrong: root 실행 시 /root/tmp.XXXX 로 생성됨
TMP=$(mktemp ~/tmp.XXXX)

# Correct: 기본값 /tmp/ 사용
TMP=$(mktemp)
```

**/etc/sysconfig/alloy CONFIG_FILE 누락**
```bash
# Wrong: Alloy systemd 서비스가 "accepts 1 arg(s), received 0" 오류로 실패
echo "" > /etc/sysconfig/alloy

# Correct
echo "CONFIG_FILE=/etc/alloy/config.alloy" > /etc/sysconfig/alloy
```
