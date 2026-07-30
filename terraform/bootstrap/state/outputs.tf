output "state_bucket_name" {
  value       = try(aws_s3_bucket.state[0].id, null)
  description = "환경별 state key를 저장할 S3 bucket"
}

output "state_kms_key_arn" {
  value       = try(aws_kms_key.state[0].arn, null)
  description = "Terraform backend.hcl에서 사용할 KMS key ARN"
}
