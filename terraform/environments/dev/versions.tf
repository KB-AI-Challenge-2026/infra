terraform {
  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = !var.enable_aws_resources
  skip_metadata_api_check     = !var.enable_aws_resources
  skip_requesting_account_id  = !var.enable_aws_resources

  default_tags {
    tags = local.tags
  }
}
