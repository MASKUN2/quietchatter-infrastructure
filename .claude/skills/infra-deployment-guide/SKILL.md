---
name: infra-deployment-guide
description: Use when deploying or validating QuietChatter infrastructure - covers Terraform provisioning order, SSM access, swap/network checks, and service status verification
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

## 서비스 구동 및 상태 확인

- 도커 상태: controlplane 노드 접속 후 docker ps 명령으로 주요 서비스 구동 확인
- Consul UI: 내부 주소 10.0.101.100의 8500 포트 활성화 여부 확인
