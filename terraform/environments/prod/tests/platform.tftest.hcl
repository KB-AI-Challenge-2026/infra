mock_provider "aws" {}

run "safe_mode_creates_no_aws_resources" {
  command = plan

  assert {
    condition     = output.vpc_id == null
    error_message = "prod 기본값은 어떤 AWS 자원도 만들면 안 됩니다."
  }

  assert {
    condition     = length(output.service_role_arns) == 0
    error_message = "prod 안전 모드에서는 IAM role을 만들면 안 됩니다."
  }
}

run "enabled_production_contract" {
  command = plan

  override_data {
    target = module.platform.data.aws_iam_policy_document.ecs_task_assume_role
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  override_data {
    target = module.platform.data.aws_iam_policy_document.backend_storage[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  override_data {
    target = module.platform.data.aws_iam_policy_document.aiserver_storage[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  variables {
    enable_aws_resources     = true
    enable_ecs_services      = true
    enable_nat_gateway       = true
    backend_ingress_cidrs    = ["203.0.113.0/24"]
    backend_certificate_arn  = "arn:aws:acm:ap-northeast-2:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    db_instance_class        = "db.t4g.small"
    db_allocated_storage     = 100
    db_backup_retention_days = 7
    document_retention_days  = 30
    document_bucket_name     = "kb-global-bridge-prod-contract-test"
    backend_image_uri        = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    aiserver_image_uri       = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/aiserver@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }

  assert {
    condition     = output.ecs_cluster_name == "kb-global-bridge-prod"
    error_message = "prod ECS cluster 이름 계약이 다릅니다."
  }

  assert {
    condition     = toset(keys(output.service_role_arns)) == toset(["backend", "aiserver"])
    error_message = "운영 서비스별 독립 task role이 필요합니다."
  }
}
