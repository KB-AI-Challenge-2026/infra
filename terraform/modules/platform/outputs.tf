output "vpc_id" {
  value = try(aws_vpc.this[0].id, null)
}

output "database_endpoint" {
  value = try(aws_db_instance.postgres[0].address, null)
}

output "database_master_secret_arn" {
  value     = try(aws_db_instance.postgres[0].master_user_secret[0].secret_arn, null)
  sensitive = true
}

output "document_bucket_name" {
  value = try(aws_s3_bucket.documents[0].id, null)
}

output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}

output "ecs_cluster_name" {
  value = try(aws_ecs_cluster.this[0].name, null)
}

output "backend_url" {
  value = try(
    "${lower(local.backend_listener_protocol)}://${aws_lb.backend[0].dns_name}",
    null
  )
}

output "aiserver_internal_url" {
  value = try("http://${aws_lb.aiserver[0].dns_name}:${local.aiserver_port}", null)
}

output "service_role_arns" {
  value = { for name, role in aws_iam_role.task : name => role.arn }
}
