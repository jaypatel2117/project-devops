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
  default = "10.10.0.0/16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "github_repo" {
  type        = string
  description = "GitHub owner/repo"
}

variable "alert_email" {
  type    = string
  default = ""
}
