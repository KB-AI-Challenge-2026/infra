resource "terraform_data" "configuration_guard" {
  count = var.enable_bootstrap_resources ? 1 : 0

  input = var.state_bucket_name

  lifecycle {
    precondition {
      condition     = length(trimspace(var.state_bucket_name)) >= 3
      error_message = "원격 state 생성 전 전 세계에서 고유한 state_bucket_name을 확정해야 합니다."
    }
  }
}

resource "aws_kms_key" "state" {
  count                   = var.enable_bootstrap_resources ? 1 : 0
  description             = "Encrypt ${var.project_name} Terraform remote state"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_kms_alias" "state" {
  count         = var.enable_bootstrap_resources ? 1 : 0
  name          = "alias/${var.project_name}-terraform-state"
  target_key_id = aws_kms_key.state[0].key_id
}

resource "aws_s3_bucket" "state" {
  count  = var.enable_bootstrap_resources ? 1 : 0
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_s3_bucket_public_access_block" "state" {
  count                   = var.enable_bootstrap_resources ? 1 : 0
  bucket                  = aws_s3_bucket.state[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  count  = var.enable_bootstrap_resources ? 1 : 0
  bucket = aws_s3_bucket.state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  count  = var.enable_bootstrap_resources ? 1 : 0
  bucket = aws_s3_bucket.state[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state[0].arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  count  = var.enable_bootstrap_resources ? 1 : 0
  bucket = aws_s3_bucket.state[0].id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state_bucket" {
  count = var.enable_bootstrap_resources ? 1 : 0

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state[0].arn,
      "${aws_s3_bucket.state[0].arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  count  = var.enable_bootstrap_resources ? 1 : 0
  bucket = aws_s3_bucket.state[0].id
  policy = data.aws_iam_policy_document.state_bucket[0].json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
