variable "enable_aws_resources" {
  description = "AWS 기반 자원 생성 여부"
  type        = bool
}

variable "enable_ecs_services" {
  description = "ECS task/service와 ALB 생성 여부"
  type        = bool
}

variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "environment" {
  description = "격리된 배포 환경 이름"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment는 dev 또는 prod여야 합니다."
  }
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "vpc_cidr" {
  description = "환경 전용 VPC CIDR"
  type        = string
}

variable "availability_zone_suffixes" {
  description = "리전 내 사용할 가용영역 suffix"
  type        = list(string)
  default     = ["a", "c"]

  validation {
    condition     = length(var.availability_zone_suffixes) >= 2
    error_message = "ALB와 RDS를 위해 최소 2개 가용영역이 필요합니다."
  }
}

variable "backend_ingress_cidrs" {
  description = "공개 Backend ALB 접근 허용 CIDR"
  type        = list(string)
}

variable "backend_certificate_arn" {
  description = "Backend HTTPS용 ACM 인증서 ARN"
  type        = string
  default     = null
  nullable    = true
}

variable "enable_nat_gateway" {
  description = "비공개 ECS subnet의 외부 통신용 NAT Gateway 생성 여부"
  type        = bool
}

variable "nat_gateway_count" {
  description = "NAT Gateway 수. dev는 1, prod는 가용영역별 구성을 권장한다."
  type        = number
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = null
  nullable    = true
}

variable "db_allocated_storage" {
  description = "RDS 저장공간(GB)"
  type        = number
  default     = null
  nullable    = true
}

variable "db_master_username" {
  description = "RDS 관리자 계정명. 서비스 계정으로 직접 사용하지 않는다."
  type        = string
  default     = "kb_admin"
}

variable "db_backup_retention_days" {
  description = "RDS 자동 백업 보존일"
  type        = number
  default     = null
  nullable    = true
}

variable "db_multi_az" {
  description = "RDS Multi-AZ 여부"
  type        = bool
}

variable "db_deletion_protection" {
  description = "RDS 삭제 보호 여부"
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "RDS 삭제 시 최종 snapshot 생략 여부"
  type        = bool
}

variable "document_retention_days" {
  description = "원본 문서 보존일. 운영 정책 확정 전에는 null을 허용한다."
  type        = number
  default     = null
  nullable    = true
}

variable "document_bucket_name" {
  description = "전 세계에서 고유한 문서 S3 bucket 이름. 운영 활성화 전 필수다."
  type        = string
  default     = null
  nullable    = true
}

variable "document_force_destroy" {
  description = "문서가 남아 있어도 버킷 삭제를 허용할지 여부"
  type        = bool
}

variable "alb_deletion_protection" {
  description = "ALB 삭제 보호 여부"
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch 서비스 로그 보존일"
  type        = number
}

variable "backend_image_uri" {
  description = "Spring Boot 불변 이미지 URI"
  type        = string
}

variable "aiserver_image_uri" {
  description = "FastAPI 불변 이미지 URI"
  type        = string
}

variable "backend_cpu" {
  description = "Backend Fargate CPU units"
  type        = number
  default     = 512
}

variable "backend_memory" {
  description = "Backend Fargate memory(MiB)"
  type        = number
  default     = 1024
}

variable "aiserver_cpu" {
  description = "AI Server Fargate CPU units"
  type        = number
  default     = 1024
}

variable "aiserver_memory" {
  description = "AI Server Fargate memory(MiB)"
  type        = number
  default     = 2048
}

variable "container_cpu_architecture" {
  description = "ECS 이미지와 일치하는 Fargate CPU architecture"
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.container_cpu_architecture)
    error_message = "container_cpu_architecture는 X86_64 또는 ARM64여야 합니다."
  }
}

variable "backend_desired_count" {
  description = "Backend ECS service desired count"
  type        = number
}

variable "aiserver_desired_count" {
  description = "AI Server ECS service desired count"
  type        = number
}

variable "service_environment" {
  description = "서비스별 비민감 환경변수"
  type        = map(map(string))
  default     = {}
}

variable "service_secrets" {
  description = "서비스별 환경변수 이름과 Secrets Manager secret/version ARN 매핑"
  type        = map(map(string))
  default     = {}
}

variable "secrets_kms_key_arns" {
  description = "비밀값 복호화에 필요한 고객 관리형 KMS key ARN"
  type        = list(string)
  default     = []
}

variable "enable_execute_command" {
  description = "ECS Exec 활성화 여부"
  type        = bool
  default     = false
}
