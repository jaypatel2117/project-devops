variable "name_prefix"          { type = string }
variable "vpc_id"               { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "blue_target_group_arn" { type = string }
variable "execution_role_arn"   { type = string }
variable "task_role_arn"        { type = string }
variable "aws_region"           { type = string }
variable "frontend_image"       { type = string }
variable "backend_image"        { type = string }
variable "db_host"              { type = string }
variable "db_name"              { type = string }
variable "db_username"          { type = string }
variable "db_secret_arn"        { type = string }
variable "alb_dns_name"         { type = string }

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "frontend_port" {
  type    = number
  default = 80
}

variable "backend_port" {
  type    = number
  default = 3001
}

variable "task_cpu" {
  type    = number
  default = 512
}

variable "task_memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 10
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "alarm_sns_arn" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
