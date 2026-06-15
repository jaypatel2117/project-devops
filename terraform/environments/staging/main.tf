terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
  backend "s3" {
    bucket         = "retail-tfstate-468094683497"
    key            = "staging/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "retail-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

data "aws_caller_identity" "current" {}

locals {
  env         = "staging"
  name_prefix = "${var.project}-${local.env}"
  common_tags = { Project = var.project, Environment = local.env, ManagedBy = "Terraform" }
}

module "vpc" {
  source      = "../../modules/vpc"
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "iam" {
  source         = "../../modules/iam"
  name_prefix    = local.name_prefix
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = local.common_tags
}

module "alb" {
  source             = "../../modules/alb"
  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  aws_account_id     = data.aws_caller_identity.current.account_id
  tags               = local.common_tags
  depends_on         = [module.vpc]
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
    description     = "Frontend from ALB"
  }

  ingress {
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
    description     = "Backend health check from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-ecs-tasks-sg" })
  depends_on = [module.alb]
}

module "rds" {
  source                = "../../modules/rds"
  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  ecs_security_group_id = aws_security_group.ecs_tasks.id
  instance_class        = var.db_instance_class
  allocated_storage     = 20
  multi_az              = true
  deletion_protection   = false
  skip_final_snapshot   = false
  backup_retention_days = 7
  tags                  = local.common_tags
}

module "ecs" {
  source                = "../../modules/ecs"
  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = aws_security_group.ecs_tasks.id
  blue_target_group_arn = module.alb.blue_target_group_arn
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  aws_region            = var.aws_region
  frontend_image        = module.ecr.frontend_repo_url
  backend_image         = module.ecr.backend_repo_url
  db_host               = module.rds.db_endpoint
  db_name               = "retaildb"
  db_username           = module.rds.db_username
  db_secret_arn         = module.rds.db_secret_arn
  alb_dns_name          = module.alb.alb_dns_name
  task_cpu              = 1024
  task_memory           = 2048
  desired_count         = 2
  min_capacity          = 2
  max_capacity          = 8
  log_retention_days    = 14
  tags                  = local.common_tags
  depends_on            = [module.alb, module.iam, module.rds]
}

module "cicd" {
  source                  = "../../modules/cicd"
  name_prefix             = local.name_prefix
  aws_account_id          = data.aws_caller_identity.current.account_id
  aws_region              = var.aws_region
  codebuild_role_arn      = module.iam.codebuild_role_arn
  codepipeline_role_arn   = module.iam.codepipeline_role_arn
  codedeploy_role_arn     = module.iam.codedeploy_role_arn
  frontend_repo_url       = module.ecr.frontend_repo_url
  backend_repo_url        = module.ecr.backend_repo_url
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  http_listener_arn       = module.alb.http_listener_arn
  test_listener_arn       = module.alb.test_listener_arn
  blue_target_group_name  = module.alb.blue_target_group_name
  green_target_group_name = module.alb.green_target_group_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  github_repo             = var.github_repo
  github_branch           = "staging"
  alert_email             = var.alert_email
  tags                    = local.common_tags
  depends_on              = [module.ecs]
}

output "app_url"    { value = "http://${module.alb.alb_dns_name}" }
output "db_endpoint"{ value = module.rds.db_endpoint }
