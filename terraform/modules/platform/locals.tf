locals {
  name            = "${var.project_name}-${var.environment}"
  services        = toset(["backend", "aiserver"])
  create_services = var.enable_aws_resources && var.enable_ecs_services

  backend_port              = 8080
  aiserver_port             = 8000
  backend_listener_port     = var.backend_certificate_arn == null ? 80 : 443
  backend_listener_protocol = var.backend_certificate_arn == null ? "HTTP" : "HTTPS"
  document_bucket_name      = var.document_bucket_name != null ? var.document_bucket_name : "${local.name}-documents"

  service_secret_arns = {
    for service in local.services :
    service => distinct(values(lookup(var.service_secrets, service, {})))
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    DataClass   = "confidential"
  }
}

resource "terraform_data" "configuration_guard" {
  count = var.enable_aws_resources ? 1 : 0

  input = local.name

  lifecycle {
    precondition {
      condition     = var.db_instance_class != null && var.db_allocated_storage != null
      error_message = "AWS 자원 활성화 전 RDS instance class와 저장공간을 확정해야 합니다."
    }

    precondition {
      condition     = var.db_backup_retention_days != null
      error_message = "AWS 자원 활성화 전 RDS 백업 보존기간을 확정해야 합니다."
    }

    precondition {
      condition     = var.document_retention_days != null
      error_message = "AWS 자원 활성화 전 개인정보 원본 문서 보존기간을 확정해야 합니다."
    }

    precondition {
      condition     = !var.enable_ecs_services || var.enable_nat_gateway
      error_message = "비공개 ECS task의 ECR·외부 공식 API 통신을 위해 NAT Gateway 비용을 명시적으로 승인해야 합니다."
    }

    precondition {
      condition     = !var.enable_ecs_services || length(var.backend_ingress_cidrs) > 0
      error_message = "ECS 서비스 활성화 전 Backend ALB의 승인된 접근 CIDR을 입력해야 합니다."
    }

    precondition {
      condition = !var.enable_ecs_services || (
        trimspace(var.backend_image_uri) != "" &&
        trimspace(var.aiserver_image_uri) != ""
      )
      error_message = "ECS 서비스 활성화 전 Backend와 AI Server의 불변 이미지 URI가 필요합니다."
    }

    precondition {
      condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= length(var.availability_zone_suffixes)
      error_message = "NAT Gateway 수는 1 이상, 가용영역 수 이하여야 합니다."
    }

    precondition {
      condition     = var.environment != "prod" || try(trimspace(var.backend_certificate_arn) != "", false)
      error_message = "운영 Backend ALB에는 ACM 인증서가 필수입니다."
    }

    precondition {
      condition     = var.environment != "prod" || try(trimspace(var.document_bucket_name) != "", false)
      error_message = "운영 활성화 전 전 세계에서 고유한 문서 bucket 이름을 확정해야 합니다."
    }

    precondition {
      condition = var.environment != "prod" || (
        var.db_multi_az &&
        var.db_deletion_protection &&
        !var.db_skip_final_snapshot &&
        var.alb_deletion_protection &&
        !var.document_force_destroy
      )
      error_message = "운영 환경은 Multi-AZ, RDS·ALB 삭제 보호, 최종 snapshot, 문서 버킷 삭제 방지를 적용해야 합니다."
    }
  }
}
