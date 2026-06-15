output "db_endpoint"           { value = aws_db_instance.main.address }
output "db_port"               { value = aws_db_instance.main.port }
output "db_name"               { value = aws_db_instance.main.db_name }
output "db_secret_arn"         { value = aws_secretsmanager_secret.Db_password.arn }
output "db_username"           { value = var.db_username }
output "rds_security_group_id" { value = aws_security_group.rds.id }

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
