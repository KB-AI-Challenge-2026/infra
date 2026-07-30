variable "enable_aws_resources" {
  description = "실제 AWS 운영 기반 자원 계획·생성 여부. 운영 승인 전에는 false를 유지한다."
  type        = bool
  default     = false
}

variable "enable_ecs_services" {
  description = "운영 ECS task/service와 ALB 생성 여부"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS 운영 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "kb-global-bridge"
}

variable "vpc_cidr" {
  description = "prod VPC CIDR. dev와 중복되면 안 된다."
  type        = string
  default     = "10.43.0.0/16"
}

variable "backend_ingress_cidrs" {
  description = "공개 Backend HTTPS ALB 접근 허용 CIDR"
  type        = list(string)
  default     = []
}

variable "backend_certificate_arn" {
  description = "운영 Backend HTTPS용 ACM 인증서 ARN. 운영 활성화 전 필수다."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_nat_gateway" {
  description = "운영 비공개 subnet 가용영역별 NAT Gateway 생성 여부"
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "부하·비용 검토로 확정한 운영 RDS 인스턴스 클래스"
  type        = string
  default     = null
  nullable    = true
}

variable "db_allocated_storage" {
  description = "용량·증가율 검토로 확정한 운영 RDS 저장공간(GB)"
  type        = number
  default     = null
  nullable    = true
}

variable "db_backup_retention_days" {
  description = "복구 목표와 개인정보 정책으로 확정한 운영 RDS 백업 보존일"
  type        = number
  default     = null
  nullable    = true
}

variable "document_retention_days" {
  description = "법무·개인정보 정책으로 확정한 운영 원본 문서 보존일"
  type        = number
  default     = null
  nullable    = true
}

variable "document_bucket_name" {
  description = "전 세계에서 고유하고 승인된 운영 문서 bucket 이름"
  type        = string
  default     = null
  nullable    = true
}

variable "log_retention_days" {
  description = "감사·개인정보 정책으로 확정한 운영 애플리케이션 로그 보존일"
  type        = number
  default     = 30
}

variable "backend_image_uri" {
  description = "승인된 Spring Boot 불변 이미지 URI"
  type        = string
  default     = ""
}

variable "aiserver_image_uri" {
  description = "승인된 FastAPI 불변 이미지 URI"
  type        = string
  default     = ""
}

variable "backend_desired_count" {
  description = "가용성·부하 검토로 확정한 Backend task 수"
  type        = number
  default     = 2
}

variable "aiserver_desired_count" {
  description = "가용성·부하 검토로 확정한 AI Server task 수"
  type        = number
  default     = 2
}

variable "service_environment" {
  description = "서비스별 비민감 운영 환경변수"
  type        = map(map(string))
  default     = {}
}

variable "service_secrets" {
  description = "서비스별 환경변수 이름과 운영 Secrets Manager secret/version ARN 매핑"
  type        = map(map(string))
  default     = {}
}

variable "secrets_kms_key_arns" {
  description = "운영 비밀값 복호화에 필요한 고객 관리형 KMS key ARN"
  type        = list(string)
  default     = []
}

variable "enable_execute_command" {
  description = "승인·감사·세션 로깅이 준비된 경우에만 ECS Exec을 활성화한다."
  type        = bool
  default     = false
}

variable "container_cpu_architecture" {
  description = "승인된 운영 이미지와 일치하는 Fargate CPU architecture"
  type        = string
  default     = "X86_64"
}
