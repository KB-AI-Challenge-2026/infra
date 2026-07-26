variable "enable_aws_resources" {
  description = "실제 AWS dev 자원 계획·생성 여부. 계정 검토 전에는 false를 유지한다."
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

variable "environment" {
  description = "환경 이름"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "dev VPC CIDR"
  type        = string
  default     = "10.42.0.0/16"
}

variable "backend_ingress_cidrs" {
  description = "Backend 8080 접근을 허용할 CIDR. 기본값은 외부 접근 차단이다."
  type        = list(string)
  default     = []
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

variable "db_master_username" {
  description = "RDS 관리자 계정명. 비밀번호는 RDS가 Secrets Manager에서 관리한다."
  type        = string
  default     = "kb_admin"
}

variable "document_retention_days" {
  description = "dev 원본 문서 보존기간"
  type        = number
  default     = 30
}
