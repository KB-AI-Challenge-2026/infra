output "vpc_id" {
  value       = module.platform.vpc_id
  description = "prod VPC ID"
}

output "database_endpoint" {
  value       = module.platform.database_endpoint
  description = "운영 PostgreSQL endpoint"
}

output "database_master_secret_arn" {
  value       = module.platform.database_master_secret_arn
  description = "RDS 관리형 관리자 비밀 ARN. 애플리케이션 계정으로 직접 사용하지 않는다."
  sensitive   = true
}

output "document_bucket_name" {
  value       = module.platform.document_bucket_name
  description = "운영 암호화 비공개 문서 버킷"
}

output "ecr_repository_urls" {
  value       = module.platform.ecr_repository_urls
  description = "운영 서비스별 ECR 저장소"
}

output "ecs_cluster_name" {
  value       = module.platform.ecs_cluster_name
  description = "운영 ECS 클러스터 이름"
}

output "backend_url" {
  value       = module.platform.backend_url
  description = "운영 Backend HTTPS ALB URL"
}

output "aiserver_internal_url" {
  value       = module.platform.aiserver_internal_url
  description = "운영 VPC 내부 AI Server ALB URL"
}

output "service_role_arns" {
  value       = module.platform.service_role_arns
  description = "운영 서비스별 task role ARN"
}
