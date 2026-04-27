---
name: infra-deployment-guide
description: Use when deploying or validating QuietChatter infrastructure - covers Terraform provisioning order, SSM access, swap/network checks, and k3s cluster verification
---

# Infra Deployment Guide

## 인프라 프로비저닝

- 테라폼을 사용하여 정의된 리소스를 생성합니다. (terraform init 및 terraform apply)
- 실행 즉시 비용이 발생하며, 생성 완료까지 약 5분에서 10분이 소요됩니다.
- 계층 실행 순서: 01-base → 02-platform → 03-apps

## 기초 인프라 검증

- SSM 접속: aws ssm start-session 명령으로 각 노드 터미널 접속 확인
- 스왑 메모리: 접속 후 free -h 명령어로 2GB 스왑 활성화 여부 확인
- 인터넷 연결: 프라이빗 노드에서 ping 8.8.8.8 명령으로 NAT 기능 확인

## k3s 클러스터 상태 확인

controlplane 노드 접속 후 아래 명령으로 확인한다.

```bash
# 노드 상태 (4노드 모두 Ready여야 함)
sudo kubectl get nodes

# 파드 상태 (quietchatter 네임스페이스)
sudo kubectl get pods -n quietchatter

# 파드 상세 이벤트 (배포 문제 진단)
sudo kubectl describe pod <pod-name> -n quietchatter

# 파드 로그
sudo kubectl logs <pod-name> -n quietchatter
```

## 노드 구성 (4노드)

- controlplane (10.0.101.100, t4g.micro): k3s server + Redis
- platform (10.0.101.120, t4g.micro): Redpanda
- gateway (퍼블릭, t4g.micro): NGINX + api-gateway
- worker ASG (t4g.small, Spot): 4개 마이크로서비스

## S3 매니페스트 배포 확인

sync.sh는 controlplane에서 5분 주기로 실행된다.

```bash
# 수동 즉시 실행
sudo -u ec2-user /home/ec2-user/sync.sh

# 타이머 상태 확인
systemctl status infra-asset-sync.timer
```
