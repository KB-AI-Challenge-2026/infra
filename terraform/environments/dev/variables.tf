variable "enable_aws_resources" {
  description = "실제 AWS dev 기반 자원 계획·생성 여부. 계정 검토 전에는 false를 유지한다."
  type        = bool
  default     = false
}

variable "enable_ecs_services" {
  description = "ECS task/service와 ALB 생성 여부. 이미지·비밀값·접근 경계 검토 전에는 false다."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS dev 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "kb-global-bridge"
}

variable "vpc_cidr" {
  description = "dev VPC CIDR"
  type        = string
  default     = "10.42.0.0/16"
}

variable "backend_ingress_cidrs" {
  description = "공개 Backend ALB 접근을 허용할 승인 CIDR. 기본값은 외부 접근 차단이다."
  type        = list(string)
  default     = []
}

variable "backend_certificate_arn" {
  description = "Backend HTTPS용 ACM 인증서 ARN. dev에서는 null이면 HTTP listener를 사용한다."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_nat_gateway" {
  description = "비공개 ECS subnet의 외부 통신용 NAT Gateway 생성 여부. 비용 검토 후 활성화한다."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "dev RDS 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "dev RDS 저장공간(GB)"
  type        = number
  default     = 20
}

variable "document_retention_days" {
  description = "dev 원본 문서 보존기간"
  type        = number
  default     = 30
}

variable "document_bucket_name" {
  description = "dev 문서 bucket 이름. null이면 프로젝트·환경 기반 이름을 사용한다."
  type        = string
  default     = null
  nullable    = true
}

variable "backend_image_uri" {
  description = "배포할 Spring Boot 불변 이미지 URI"
  type        = string
  default     = ""
}

variable "aiserver_image_uri" {
  description = "배포할 FastAPI 불변 이미지 URI"
  type        = string
  default     = ""
}

variable "service_environment" {
  description = "서비스별 비민감 환경변수. 비밀값은 service_secrets로만 전달한다."
  type        = map(map(string))
  default     = {}
}

variable "service_secrets" {
  description = "서비스별 환경변수 이름과 기존 Secrets Manager secret/version ARN 매핑"
  type        = map(map(string))
  default     = {}
}

variable "secrets_kms_key_arns" {
  description = "ECS가 비밀값 복호화에 사용할 고객 관리형 KMS key ARN"
  type        = list(string)
  default     = []
}

variable "enable_execute_command" {
  description = "감사된 장애대응 절차가 있을 때만 ECS Exec을 활성화한다."
  type        = bool
  default     = false
}

variable "container_cpu_architecture" {
  description = "배포 이미지와 일치하는 Fargate CPU architecture"
  type        = string
  default     = "X86_64"
}
