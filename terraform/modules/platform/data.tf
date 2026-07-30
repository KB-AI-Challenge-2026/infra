resource "aws_db_subnet_group" "this" {
  count      = var.enable_aws_resources ? 1 : 0
  name       = "${local.name}-db"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name}-db" }
}

resource "aws_db_instance" "postgres" {
  count                       = var.enable_aws_resources ? 1 : 0
  identifier                  = "${local.name}-postgres"
  engine                      = "postgres"
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "kbai"
  username                    = var.db_master_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.this[0].name
  vpc_security_group_ids      = [aws_security_group.database[0].id]
  publicly_accessible         = false
  multi_az                    = var.db_multi_az
  backup_retention_period     = var.db_backup_retention_days
  deletion_protection         = var.db_deletion_protection
  skip_final_snapshot         = var.db_skip_final_snapshot
  final_snapshot_identifier   = var.db_skip_final_snapshot ? null : "${local.name}-postgres-final"
  auto_minor_version_upgrade  = true
  apply_immediately           = false

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_s3_bucket" "documents" {
  count         = var.enable_aws_resources ? 1 : 0
  bucket        = local.document_bucket_name
  force_destroy = var.document_force_destroy

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_s3_bucket_public_access_block" "documents" {
  count                   = var.enable_aws_resources ? 1 : 0
  bucket                  = aws_s3_bucket.documents[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  count  = var.enable_aws_resources ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  count  = var.enable_aws_resources ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  count  = var.enable_aws_resources ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  rule {
    id     = "document-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = var.document_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.document_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.documents]
}

resource "aws_ecr_repository" "service" {
  for_each             = var.enable_aws_resources ? local.services : toset([])
  name                 = "${local.name}-${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the latest 20 immutable images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = var.enable_aws_resources ? local.services : toset([])
  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = var.log_retention_days
}
