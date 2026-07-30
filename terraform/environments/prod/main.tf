module "platform" {
  source = "../../modules/platform"

  enable_aws_resources = var.enable_aws_resources
  enable_ecs_services  = var.enable_ecs_services

  project_name = var.project_name
  environment  = "prod"
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr

  backend_ingress_cidrs   = var.backend_ingress_cidrs
  backend_certificate_arn = var.backend_certificate_arn
  enable_nat_gateway      = var.enable_nat_gateway
  nat_gateway_count       = 2

  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_backup_retention_days = var.db_backup_retention_days
  db_multi_az              = true
  db_deletion_protection   = true
  db_skip_final_snapshot   = false

  document_retention_days = var.document_retention_days
  document_bucket_name    = var.document_bucket_name
  document_force_destroy  = false
  alb_deletion_protection = true
  log_retention_days      = var.log_retention_days

  backend_desired_count      = var.backend_desired_count
  aiserver_desired_count     = var.aiserver_desired_count
  backend_image_uri          = var.backend_image_uri
  aiserver_image_uri         = var.aiserver_image_uri
  service_environment        = var.service_environment
  service_secrets            = var.service_secrets
  secrets_kms_key_arns       = var.secrets_kms_key_arns
  enable_execute_command     = var.enable_execute_command
  container_cpu_architecture = var.container_cpu_architecture
}
