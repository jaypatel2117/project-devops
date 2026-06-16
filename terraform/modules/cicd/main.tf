# ── Artifact S3 Bucket ───────────────────────────────────────────
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name_prefix}-pipeline-artifacts-${var.aws_account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── SNS Topic for Approvals & Alerts ─────────────────────────────
resource "aws_sns_topic" "pipeline_alerts" {
  name = "${var.name_prefix}-pipeline-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CodeBuild — Build & Test ─────────────────────────────────────
resource "aws_codebuild_project" "build" {
  name          = "${var.name_prefix}-build"
  description   = "Build and push Docker images to ECR"
  build_timeout = 20
  service_role  = var.codebuild_role_arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required for Docker builds
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "FRONTEND_REPO"
      value = var.frontend_repo_url
    }
    environment_variable {
      name  = "BACKEND_REPO"
      value = var.backend_repo_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.name_prefix}-build"
      stream_name = "build-log"
    }
  }

  tags = var.tags
}

# ── CodeDeploy Application ────────────────────────────────────────
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = "${var.name_prefix}-app"
  tags             = var.tags
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${var.name_prefix}-dg"
  service_role_arn       = var.codedeploy_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    alarms  = ["${var.name_prefix}-alb-5xx", "${var.name_prefix}-ecs-cpu-high"]
    enabled = true
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route { listener_arns = [var.http_listener_arn] }
      test_traffic_route { listener_arns = [var.test_listener_arn] }

      target_group { name = var.blue_target_group_name }
      target_group { name = var.green_target_group_name }
    }
  }

  tags = var.tags
}

# ── CodeStar Connection (GitHub) ─────────────────────────────────
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.name_prefix}-github"
  provider_type = "GitHub"
  tags          = var.tags
}

# ── CodePipeline ──────────────────────────────────────────────────
resource "aws_codepipeline" "main" {
  name     = "${var.name_prefix}-pipeline"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # Stage 1: Source
  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repo
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  # Stage 2: Build
  stage {
    name = "Build"
    action {
      name             = "Build_and_Push"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  # Stage 3: Deploy to Staging (ECS Blue/Green)
  stage {
    name = "Deploy_Staging"
    action {
      name            = "Deploy_ECS_BG"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.main.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            = "appspec.yml"
      }
    }
  }

  # Stage 4: Manual Approval before Production
  stage {
    name = "Approve_Production"
    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        NotificationArn = aws_sns_topic.pipeline_alerts.arn
        CustomData      = "Approve deployment to Production? Staging validation passed."
      }
    }
  }

  tags = var.tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.name_prefix}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "ECS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
          period = 300
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ECS Memory Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
          period = 300
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
          period = 60
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB 5XX Errors"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix]]
          period = 60
        }
      }
    ]
  })
}
