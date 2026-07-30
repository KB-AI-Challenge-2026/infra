# Infrastructure

로컬 pgvector 포함 PostgreSQL, OpenTelemetry Collector, FastAPI, Spring Boot를
Docker Compose로 실행합니다. 운영 환경에서는 비밀값을 환경변수·Secret
Manager로 교체해야 합니다.

클라우드 배포 인프라는 Terraform으로 관리합니다. 현재 도입 범위와 운영 원칙은 [Terraform 인프라 설계](../docs/INFRASTRUCTURE_TERRAFORM.md)를 따릅니다. Docker Compose는 로컬 개발용이며, 클라우드 콘솔의 수동 설정을 운영 기준으로 사용하지 않습니다.

호스트의 기존 PostgreSQL과 충돌하지 않도록 개발 DB는 `localhost:55432`를 사용합니다.
OTLP/HTTP 수신 포트는 `localhost:4318`입니다. 로컬 Collector의 `debug`
exporter는 수신 확인용이며 운영 저장소가 아닙니다.

## 실행

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
```

## 스키마 소유권

- `core`: Spring Boot + Flyway (`kb_backend_user`)
- `ai`, `rag`: FastAPI/AIServer (`kb_ai_user`)
- 두 서비스는 상대 서비스의 업무 테이블을 직접 수정하지 않습니다.
- 스키마와 계정은 `infra`가 생성하고, 스키마 내부 테이블은 각 서비스 마이그레이션이 관리합니다.

PostgreSQL 초기 계정은 로컬 개발 전용입니다. 이미 생성된 볼륨에는 초기화 SQL이 다시 적용되지 않으므로 계정·스키마를 변경할 때는 별도 마이그레이션으로 처리합니다.
기존 `postgres:16` 볼륨을 유지한 채 pgvector 이미지로 바꾸는 경우 관리자
계정으로 `CREATE EXTENSION IF NOT EXISTS vector`를 한 번 적용한 뒤 AI Server
Alembic migration과 공식자료 ingest를 실행합니다. 새 볼륨은 초기화 SQL에서
확장을 자동 생성합니다.

## Terraform

Terraform 코드는 `infra/terraform` 아래에 있습니다. dev·prod와 원격 state 상세 절차는
[Terraform README](./terraform/README.md)를 따릅니다.

- 클라우드 공급자·계정·리전 확정 전에는 실제 자원을 `apply`하지 않습니다.
- 개발과 운영은 별도 state와 변수 집합을 사용합니다.
- Spring Boot는 외부 ALB, FastAPI는 내부 ALB와 별도 ECS service로 유지합니다.
- 서비스별 execution role과 task role을 공유하지 않습니다.
- state와 비밀값은 Git에 커밋하지 않습니다.
- 변경 전 `terraform fmt -check`, `terraform validate`, `terraform plan`,
  `terraform test`를 수행합니다.
