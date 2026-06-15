variable "name_prefix"    { type = string }
variable "vpc_id"         { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "aws_account_id" { type = string }

variable "frontend_port" {
  type    = number
  default = 80
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "alarm_sns_arn" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
