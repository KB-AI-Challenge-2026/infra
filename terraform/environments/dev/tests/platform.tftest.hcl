mock_provider "aws" {}

run "safe_mode_creates_no_aws_resources" {
  command = plan

  assert {
    condition     = output.vpc_id == null
    error_message = "dev 안전 모드에서는 VPC를 만들면 안 됩니다."
  }

  assert {
    condition     = length(output.service_role_arns) == 0
    error_message = "dev 안전 모드에서는 IAM role을 만들면 안 됩니다."
  }
}

run "enabled_service_contract" {
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
    enable_aws_resources  = true
    enable_ecs_services   = true
    enable_nat_gateway    = true
    backend_ingress_cidrs = ["203.0.113.0/24"]
    backend_image_uri     = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    aiserver_image_uri    = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/aiserver@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    document_bucket_name  = "kb-global-bridge-dev-contract-test"
  }

  assert {
    condition     = output.ecs_cluster_name == "kb-global-bridge-dev"
    error_message = "dev ECS cluster 이름 계약이 다릅니다."
  }

  assert {
    condition     = toset(keys(output.service_role_arns)) == toset(["backend", "aiserver"])
    error_message = "Backend와 AI Server task role이 각각 생성되어야 합니다."
  }
}
