mock_provider "aws" {}

run "safe_mode_creates_nothing" {
  command = plan

  assert {
    condition     = output.state_bucket_name == null
    error_message = "안전 모드에서는 원격 state 자원을 만들면 안 됩니다."
  }
}

run "enabled_state_backend_contract" {
  command = plan

  variables {
    enable_bootstrap_resources = true
    state_bucket_name          = "kb-global-bridge-test-terraform-state"
  }
}

run "enabled_state_backend_requires_bucket_name" {
  command = plan

  variables {
    enable_bootstrap_resources = true
    state_bucket_name          = ""
  }

  expect_failures = [
    terraform_data.configuration_guard
  ]
}
