<div align="center">

# KB NEST Infrastructure

### 금융 권한과 AI 처리를 분리한 안전한 서비스 기반

</div>

![KB NEST 시스템 아키텍처](https://raw.githubusercontent.com/KB-AI-Challenge-2026/.github/main/images/system-architecture.png)

## Platform

- Flutter 고객 앱과 React 상담원 웹의 공통 서비스 기반
- Spring Boot와 FastAPI의 서비스·권한·스키마 분리
- PostgreSQL 및 pgvector 기반 금융 상태·AI·RAG 데이터 관리
- OpenTelemetry와 Datadog 기반 관측성
- Airflow 기반 데이터 품질·평가 파이프라인
- Terraform 기반 클라우드 인프라 관리

## AI Service Flow

![KB NEST Agent 워크플로](https://raw.githubusercontent.com/KB-AI-Challenge-2026/.github/main/images/agent-architecture.png)

## Team

| 이름 | 역할 |
| --- | --- |
| 류은준 | 기획 |
| 최성현 | BE |
| 박민정 | Lead · AI · FE · Infra |
