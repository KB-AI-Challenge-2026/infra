resource "aws_ecs_cluster" "this" {
  count = var.enable_aws_resources ? 1 : 0
  name  = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb" "backend" {
  count                      = local.create_services ? 1 : 0
  name                       = "${local.name}-public"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.public_alb[0].id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = var.alb_deletion_protection
  drop_invalid_header_fields = true
}

resource "aws_lb" "aiserver" {
  count                      = local.create_services ? 1 : 0
  name                       = "${local.name}-internal"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.internal_alb[0].id]
  subnets                    = aws_subnet.private[*].id
  enable_deletion_protection = var.alb_deletion_protection
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "backend" {
  count       = local.create_services ? 1 : 0
  name        = "${local.name}-backend"
  port        = local.backend_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this[0].id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/api/v1/health/ready"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "aiserver" {
  count       = local.create_services ? 1 : 0
  name        = "${local.name}-aiserver"
  port        = local.aiserver_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this[0].id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/api/v1/health/ready"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "backend" {
  count = local.create_services ? 1 : 0

  load_balancer_arn = aws_lb.backend[0].arn
  port              = local.backend_listener_port
  protocol          = local.backend_listener_protocol
  certificate_arn   = var.backend_certificate_arn
  ssl_policy        = var.backend_certificate_arn == null ? null : "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }
}

resource "aws_lb_listener" "aiserver" {
  count = local.create_services ? 1 : 0

  load_balancer_arn = aws_lb.aiserver[0].arn
  port              = local.aiserver_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aiserver[0].arn
  }
}

resource "aws_ecs_task_definition" "backend" {
  count                    = local.create_services ? 1 : 0
  family                   = "${local.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.backend_cpu)
  memory                   = tostring(var.backend_memory)
  execution_role_arn       = aws_iam_role.execution["backend"].arn
  task_role_arn            = aws_iam_role.task["backend"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.container_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image_uri
    essential = true
    portMappings = [{
      containerPort = local.backend_port
      hostPort      = local.backend_port
      protocol      = "tcp"
    }]
    environment = [
      for name, value in merge(
        {
          SERVER_PORT          = tostring(local.backend_port)
          AI_BASE_URL          = "http://${aws_lb.aiserver[0].dns_name}:${local.aiserver_port}"
          DOCUMENT_BUCKET_NAME = aws_s3_bucket.documents[0].id
          AWS_REGION           = var.aws_region
        },
        lookup(var.service_environment, "backend", {})
        ) : {
        name  = name
        value = value
      }
    ]
    secrets = [
      for name, value_from in lookup(var.service_secrets, "backend", {}) : {
        name      = name
        valueFrom = value_from
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["backend"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_ecs_task_definition" "aiserver" {
  count                    = local.create_services ? 1 : 0
  family                   = "${local.name}-aiserver"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.aiserver_cpu)
  memory                   = tostring(var.aiserver_memory)
  execution_role_arn       = aws_iam_role.execution["aiserver"].arn
  task_role_arn            = aws_iam_role.task["aiserver"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.container_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "aiserver"
    image     = var.aiserver_image_uri
    essential = true
    portMappings = [{
      containerPort = local.aiserver_port
      hostPort      = local.aiserver_port
      protocol      = "tcp"
    }]
    environment = [
      for name, value in merge(
        {
          SERVER_PORT          = tostring(local.aiserver_port)
          DOCUMENT_BUCKET_NAME = aws_s3_bucket.documents[0].id
          AWS_REGION           = var.aws_region
        },
        lookup(var.service_environment, "aiserver", {})
        ) : {
        name  = name
        value = value
      }
    ]
    secrets = [
      for name, value_from in lookup(var.service_secrets, "aiserver", {}) : {
        name      = name
        valueFrom = value_from
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["aiserver"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  depends_on = [terraform_data.configuration_guard]
}

resource "aws_ecs_service" "backend" {
  count                  = local.create_services ? 1 : 0
  name                   = "backend"
  cluster                = aws_ecs_cluster.this[0].id
  task_definition        = aws_ecs_task_definition.backend[0].arn
  desired_count          = var.backend_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.backend[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend[0].arn
    container_name   = "backend"
    container_port   = local.backend_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.backend]
}

resource "aws_ecs_service" "aiserver" {
  count                  = local.create_services ? 1 : 0
  name                   = "aiserver"
  cluster                = aws_ecs_cluster.this[0].id
  task_definition        = aws_ecs_task_definition.aiserver[0].arn
  desired_count          = var.aiserver_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.aiserver[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.aiserver[0].arn
    container_name   = "aiserver"
    container_port   = local.aiserver_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.aiserver]
}
