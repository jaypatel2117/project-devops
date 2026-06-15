variable "project" {
  type    = string
  default = "retail"
}

variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "github_repo" {
  type = string
}

variable "alert_email" {
  type    = string
  default = ""
}
