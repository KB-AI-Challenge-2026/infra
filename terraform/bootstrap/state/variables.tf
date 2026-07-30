variable "enable_bootstrap_resources" {
  description = "원격 state 기반 자원을 실제 생성할지 여부"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "state 저장 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 태그"
  type        = string
  default     = "kb-global-bridge"
}

variable "state_bucket_name" {
  description = "전 세계에서 고유한 Terraform state S3 bucket 이름"
  type        = string
  default     = ""
}

variable "noncurrent_version_retention_days" {
  description = "이전 state 버전 보존일"
  type        = number
  default     = 90
}
