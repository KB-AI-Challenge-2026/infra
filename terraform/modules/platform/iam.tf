data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  for_each = var.enable_aws_resources ? local.services : toset([])

  name               = "${local.name}-${each.key}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  for_each = aws_iam_role.execution

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  for_each = var.enable_aws_resources ? {
    for service, arns in local.service_secret_arns : service => arns
    if length(arns) > 0
  } : {}

  statement {
    sid       = "ReadApprovedServiceSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = each.value
  }

  dynamic "statement" {
    for_each = length(var.secrets_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptApprovedSecretKeys"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.secrets_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  for_each = data.aws_iam_policy_document.execution_secrets

  name   = "approved-service-secrets"
  role   = aws_iam_role.execution[each.key].id
  policy = each.value.json
}

resource "aws_iam_role" "task" {
  for_each = var.enable_aws_resources ? local.services : toset([])

  name               = "${local.name}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "backend_storage" {
  count = var.enable_aws_resources ? 1 : 0

  statement {
    sid       = "ListDocumentBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.documents[0].arn]
  }

  statement {
    sid    = "ManageApprovedDocuments"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.documents[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "backend_storage" {
  count = var.enable_aws_resources ? 1 : 0

  name   = "document-storage"
  role   = aws_iam_role.task["backend"].id
  policy = data.aws_iam_policy_document.backend_storage[0].json
}

data "aws_iam_policy_document" "aiserver_storage" {
  count = var.enable_aws_resources ? 1 : 0

  statement {
    sid       = "ListDocumentBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.documents[0].arn]
  }

  statement {
    sid       = "ReadApprovedDocuments"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "aiserver_storage" {
  count = var.enable_aws_resources ? 1 : 0

  name   = "read-document-storage"
  role   = aws_iam_role.task["aiserver"].id
  policy = data.aws_iam_policy_document.aiserver_storage[0].json
}
