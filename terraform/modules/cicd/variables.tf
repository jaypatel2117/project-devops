variable "name_prefix"           { type = string }
variable "aws_account_id"        { type = string }
variable "aws_region"            { type = string }
variable "codebuild_role_arn"    { type = string }
variable "codepipeline_role_arn" { type = string }
variable "codedeploy_role_arn"   { type = string }
variable "frontend_repo_url"     { type = string }
variable "backend_repo_url"      { type = string }
variable "ecs_cluster_name"      { type = string }
variable "ecs_service_name"      { type = string }
variable "http_listener_arn"     { type = string }
variable "test_listener_arn"     { type = string }
variable "blue_target_group_name"  { type = string }
variable "green_target_group_name" { type = string }
variable "github_repo" {
  type        = string
  description = "owner/repo-name"
}

variable "alb_arn_suffix" {
  type    = string
  default = ""
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
