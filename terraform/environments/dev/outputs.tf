output "app_url"              { value = "http://${module.alb.alb_dns_name}" }
output "frontend_ecr_url"    { value = module.ecr.frontend_repo_url }
output "backend_ecr_url"     { value = module.ecr.backend_repo_url }
output "db_endpoint"         { value = module.rds.db_endpoint }
output "ecs_cluster_name"    { value = module.ecs.cluster_name }
output "pipeline_name"       { value = module.cicd.pipeline_name }
output "github_connection_arn" { value = module.cicd.github_connection_arn }
