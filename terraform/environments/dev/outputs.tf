output "vpc_id" {
  value       = try(aws_vpc.this[0].id, null)
  description = "dev VPC ID"
}

output "database_endpoint" {
  value       = try(aws_db_instance.postgres[0].address, null)
  description = "PostgreSQL endpoint"
}

output "database_master_secret_arn" {
  value       = try(aws_db_instance.postgres[0].master_user_secret[0].secret_arn, null)
  description = "RDS 관리형 관리자 비밀 ARN"
  sensitive   = true
}

output "document_bucket_name" {
  value       = try(aws_s3_bucket.documents[0].id, null)
  description = "암호화된 비공개 문서 버킷"
}

output "ecr_repository_urls" {
  value       = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
  description = "서비스별 ECR 저장소"
}

output "ecs_cluster_name" {
  value       = try(aws_ecs_cluster.this[0].name, null)
  description = "ECS 클러스터 이름"
}
