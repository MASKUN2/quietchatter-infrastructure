---
name: update-project-guidelines
description: "프로젝트 인프라의 변경 사항을 AGENTS.md, docs/update-log-*.md 및 docs/architecture-strategy.md에 반영합니다. 인프라 리소스 수정, 설정 변경 또는 작업 절차의 변화가 있을 때 반드시 사용합니다."
---

# Update Project Guidelines

이 기술은 QuietChatter 인프라 모듈의 변경 사항이 문서화 지침과 일치하도록 관리합니다. 모든 변경 사항은 추적 가능해야 하며, 에이전트의 향후 작업에 영향을 미치는 지침은 즉시 반영되어야 합니다.

## 1. 변경 사항 분석 (Analyze Changes)

작업이 완료되거나 주요 변경이 발생하면 다음 사항을 검토합니다:
- **인프라 리소스**: 새로운 테라폼 리소스 추가, 수정 또는 삭제 여부.
- **설정 변경**: Nginx, Docker Compose, Alloy 등의 템플릿 또는 설정값 변화.
- **작업 절차**: AGENTS.md에 정의된 '정보 습득 순서'나 '작업 원칙'을 수정해야 하는 교훈(Lessons Learned) 발생 여부.
- **전략 변화**: docs/architecture-strategy.md에 기술된 비용 최적화 또는 노드 구성 전략의 변화.

## 2. 문서 업데이트 워크플로우 (Documentation Workflow)

### A. 업데이트 로그 기록 (docs/update-log-YYYYMMDD.md)
1. 현재 날짜(`YYYY-MM-DD`)를 확인합니다.
2. `docs/update-log-YYYYMMDD.md` 파일이 존재하는지 확인합니다.
   - 존재하면: 기존 내용 아래에 새로운 섹션을 추가합니다.
   - 없으면: 새로 생성하고 `# 인프라 업데이트 로그 - YYYY-MM-DD` 제목을 추가합니다.
3. 변경 사항의 요약, 수정된 파일 목록, 적용 방법(예: `terraform apply` 필요 여부)을 명확히 기록합니다.

### B. 에이전트 가이드 업데이트 (AGENTS.md)
1. 새로운 기술적 교훈이나 작업 시 주의사항이 발견된 경우 `## 4. 주요 기술적 교훈 (Lessons Learned)` 섹션에 추가합니다.
2. 계층 구조나 명명 규칙 등 핵심 원칙이 변경된 경우 해당 섹션을 수정합니다.

### C. 아키텍처 전략 업데이트 (docs/architecture-strategy.md)
1. 인스턴스 사양, 비용 최적화 전략, 서비스 배치 구조가 변경된 경우 해당 문서를 최신화합니다.

## 3. 작성 규칙 (Writing Rules)

- **Plain Text Only**: 강조 서식(bold, italics), 표, 이모티콘을 절대 사용하지 않습니다.
- **Professional Tone**: 명확하고 간결하며 전문적인 어조를 유지합니다.
- **Consistency**: 기존 문서의 스타일과 구조를 따릅니다.

## 4. 완료 후 제안 (Post-Update Proposal)

문서 업데이트가 완료되면 사용자에게 변경된 문서 목록을 알리고, 필요 시 추가적인 지침 수정이 필요한지 확인을 요청합니다.
