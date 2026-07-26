locals {
  name = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    DataClass   = "confidential"
  }
}

resource "aws_vpc" "this" {
  count                = var.enable_aws_resources ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_subnet" "private" {
  count             = var.enable_aws_resources ? 2 : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "c"}"

  tags = { Name = "${local.name}-private-${count.index + 1}" }
}

resource "aws_security_group" "backend" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-backend"
  description = "Spring Boot ingress and egress"
  vpc_id      = aws_vpc.this[0].id

  dynamic "ingress" {
    for_each = var.backend_ingress_cidrs
    content {
      description = "Approved backend client"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "aiserver" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-aiserver"
  description = "FastAPI accepts only backend traffic"
  vpc_id      = aws_vpc.this[0].id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-database"
  description = "PostgreSQL access from isolated application services"
  vpc_id      = aws_vpc.this[0].id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.backend[0].id,
      aws_security_group.aiserver[0].id
    ]
  }
}

resource "aws_db_subnet_group" "this" {
  count      = var.enable_aws_resources ? 1 : 0
  name       = "${local.name}-db"
  subnet_ids = aws_subnet.private[*].id
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
  backup_retention_period     = 1
  deletion_protection         = false
  skip_final_snapshot         = true
  apply_immediately           = false
}

resource "aws_s3_bucket" "documents" {
  count  = var.enable_aws_resources ? 1 : 0
  bucket = "${local.name}-documents"
}

resource "aws_s3_bucket_public_access_block" "documents" {
  count                   = var.enable_aws_resources ? 1 : 0
  bucket                  = aws_s3_bucket.documents[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
    expiration { days = var.document_retention_days }
  }
}

resource "aws_ecr_repository" "service" {
  for_each             = var.enable_aws_resources ? toset(["backend", "aiserver"]) : toset([])
  name                 = "${local.name}-${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecs_cluster" "this" {
  count = var.enable_aws_resources ? 1 : 0
  name  = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = var.enable_aws_resources ? toset(["backend", "aiserver"]) : toset([])
  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = 14
}
