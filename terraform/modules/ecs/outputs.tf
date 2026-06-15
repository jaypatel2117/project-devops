output "cluster_name"          { value = aws_ecs_cluster.main.name }
output "cluster_arn"           { value = aws_ecs_cluster.main.arn }
output "service_name"          { value = aws_ecs_service.app.name }
output "task_definition_arn"   { value = aws_ecs_task_definition.app.arn }
output "ecs_security_group_id" { value = var.ecs_security_group_id }
output "frontend_log_group"    { value = aws_cloudwatch_log_group.frontend.name }
output "backend_log_group"     { value = aws_cloudwatch_log_group.backend.name }
