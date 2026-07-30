# Terraform AWS 배포 구성

이 디렉터리는 Spring Boot와 FastAPI를 별도 ECS/Fargate 서비스로 배포하는 AWS
인프라를 정의합니다. 저장소 기본값에서는 AWS 자원을 만들지 않으며 `apply`를
자동 실행하지 않습니다.

## 구현 범위

- 환경별 VPC, 2개 가용영역의 public/private subnet과 route table
- 비용을 명시적으로 승인해야 생성되는 NAT Gateway
- 외부 Spring Boot ALB와 VPC 내부 FastAPI ALB
- Backend·AI Server ECS task definition/service와 배포 circuit breaker
- 서비스별 ECS execution role/task role과 최소 S3·Secrets Manager 권한
- 암호화 RDS PostgreSQL, 비공개·버전 관리 S3, ECR, CloudWatch
- dev/prod 별도 root module·변수·state key
- S3 versioning·KMS·lockfile 기반 원격 state bootstrap
- 실제 AWS 호출 없는 안전 plan과 mock provider 활성화 경로 테스트

외부에는 Spring Boot ALB만 노출합니다. FastAPI ALB와 두 ECS service, RDS는
private subnet에 배치하며 FastAPI는 Backend security group에서만 접근할 수
있습니다. FastAPI에 금융 실행 권한은 부여하지 않습니다.

## 디렉터리

```text
terraform/
├── bootstrap/state/        # 원격 state용 S3·KMS
├── modules/platform/       # 공통 AWS 플랫폼 모듈
└── environments/
    ├── dev/
    └── prod/
```

## 계정 없이 검증

세 root 모두 기본 플래그가 `false`이므로 실제 자원을 만들지 않습니다.

```bash
terraform fmt -check -recursive terraform

terraform -chdir=terraform/bootstrap/state init -backend=false
terraform -chdir=terraform/bootstrap/state validate
terraform -chdir=terraform/bootstrap/state plan
terraform -chdir=terraform/bootstrap/state test

terraform -chdir=terraform/environments/dev init -backend=false
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
terraform -chdir=terraform/environments/dev test

terraform -chdir=terraform/environments/prod init -backend=false
terraform -chdir=terraform/environments/prod validate
terraform -chdir=terraform/environments/prod plan
terraform -chdir=terraform/environments/prod test
```

안전 plan에서 허용되는 변화는 빈 output 저장뿐이며 AWS 자원 변화는 0건이어야
합니다. `terraform test`는 mock provider로 ECS·ALB·IAM을 활성화한 경로도
검증합니다.

## 원격 state 전환

원격 backend 자체는 같은 state에 의존할 수 없으므로 별도 bootstrap root로
먼저 생성합니다.

1. AWS 계정, state bucket의 전 세계 고유 이름, CI 운영 주체와 비용을 승인합니다.
2. `bootstrap/state/terraform.tfvars.example`을 참고한 Git 제외 변수 파일에서
   `enable_bootstrap_resources=true`와 bucket 이름을 지정합니다.
3. bootstrap plan을 검토·승인한 뒤에만 apply합니다.
4. 출력된 bucket 이름과 KMS ARN을 환경별 `backend.hcl.example` 형식으로
   작성합니다. AWS access key나 token은 파일에 쓰지 않습니다.
5. 환경의 `backend.tf.example`을 `backend.tf`로 복사한 후 아래처럼 기존 local
   state를 명시적으로 이동합니다.

```bash
terraform -chdir=terraform/environments/dev init \
  -migrate-state \
  -backend-config=backend.hcl
```

prod는 별도 key를 사용하며 CI role의 prod state 쓰기 권한을 더 좁게 제한합니다.
S3 `use_lockfile=true`를 사용합니다. 신규 구성에는 폐기 예정인 DynamoDB locking을
추가하지 않습니다. bootstrap state 자체의 장기 보관 위치와 복구 책임은 클라우드
계정 담당자가 별도로 승인해야 합니다.

## 실제 환경 활성화

두 단계 플래그를 사용합니다.

- `enable_aws_resources=true`: VPC, RDS, S3, ECR, ECS cluster와 IAM 기반 자원
- `enable_ecs_services=true`: 이미지·NAT·접근 CIDR 검사를 통과한 ECS/ALB

서비스 활성화 전 다음 값을 확정해야 합니다.

- AWS 계정·리전·예산과 승인된 Backend 접근 CIDR
- NAT Gateway 비용
- ECR digest로 고정된 Backend·AI Server 이미지 URI와 CPU architecture
- 서비스별 CPU·메모리·desired count
- DB 크기·백업 보존·복구 목표
- 개인정보 원본 문서 보존일과 전 세계에서 고유한 S3 bucket 이름
- prod ACM 인증서와 도메인
- 운영 로그 보존일
- Secrets Manager ARN과 고객 관리형 KMS ARN

prod는 위 값 외에도 Multi-AZ, RDS·ALB 삭제 보호, 최종 snapshot, 문서 bucket
강제 삭제 금지를 코드로 강제합니다. 값이 없으면 plan이 실패하며 임의 기본값으로
우회하지 않습니다.

## 비밀값 계약

비밀값 자체를 `.tf`, `.tfvars`, container environment 또는 output에 쓰지 않습니다.
`service_secrets`에는 기존 Secrets Manager의 secret/version ARN만 전달합니다.
예시는 다음과 같습니다.

```hcl
service_secrets = {
  backend = {
    DB_URL      = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
    DB_USERNAME = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
    DB_PASSWORD = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
  }
  aiserver = {
    DATABASE_URL          = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
    LAW_OPEN_API_OC       = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
    FSS_FINLIFE_AUTH_KEY  = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
    DISCORD_WEBHOOK_URL   = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:..."
  }
}
```

ECS execution role만 승인된 secret을 읽으며 task role과 서비스별 secret 목록을
분리합니다. RDS 관리형 master secret은 애플리케이션 접속에 사용하지 않습니다.
`core`와 `ai`/`rag` 전용 DB 계정·secret 생성 절차는 Backend·AI Server 스키마
소유권에 맞춰 배포 파이프라인에서 별도로 확정해야 합니다.

## 인수인계가 필요한 경계

- Backend는 현재 로컬 파일 저장 구현이므로 S3 adapter가 연결되기 전에는
  `DOCUMENT_BUCKET_NAME`과 준비된 S3 task 권한을 실제로 사용하지 않습니다.
- AI Server도 배포 이미지에서 문서 입력 방식과 S3 읽기 계약을 확인해야 합니다.
- 서비스별 DB URL·계정 secret, 이미지 digest, ACM 인증서·도메인은 아직 실제
  계정 값이 없으므로 생성하거나 추측하지 않았습니다.
- 운영 Airflow는 관리형 Airflow와 ECS 중 선택, 메타DB, worker 규모, private UI
  접근 방식이 확정되지 않아 이 모듈에 포함하지 않았습니다.
- 실제 계정에 대한 plan/apply, CloudWatch alarm·WAF·ALB access log·autoscaling은
  트래픽·SLA·감사 기준 확정 후 후속 작업입니다.

Docker Compose는 계속 로컬 개발 전용이며 운영 기준으로 사용하지 않습니다.
