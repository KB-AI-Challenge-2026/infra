# Terraform dev 환경

`environments/dev`는 AWS 기준 VPC, 서비스별 보안그룹, 암호화 RDS PostgreSQL,
비공개 문서 S3, ECR, ECS 클러스터와 CloudWatch 로그 그룹을 정의합니다.

기본값 `enable_aws_resources=false`는 클라우드 계정 없이도 계약과 구성을 검증하기
위한 안전 모드입니다. 이 상태의 plan은 실제 자원을 만들지 않습니다.

```bash
cd infra/terraform/environments/dev
terraform init
terraform fmt -check -recursive ../..
terraform validate
terraform plan -out=dev.tfplan
```

실제 dev plan은 AWS 계정·예산·리전·접근 CIDR을 검토하고 자격 증명을 설정한 뒤
별도 `*.auto.tfvars`에서 `enable_aws_resources=true`로 바꿉니다. `apply`는 승인된
plan과 CI/CD 경로에서만 수행합니다. RDS 관리자 비밀번호는 Terraform 변수로 받지
않고 RDS가 Secrets Manager에서 관리합니다.

현재 ECS task definition과 service, 외부 Load Balancer, 원격 state backend는
배포 계정·도메인·이미지 URI·공유 state 저장소가 확정되지 않아 의도적으로
구현하지 않았습니다. 후속 단계에서 서비스별 IAM role과 함께 추가해야 합니다.
