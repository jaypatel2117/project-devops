output "pipeline_name"        { value = aws_codepipeline.main.name }
output "artifact_bucket"      { value = aws_s3_bucket.artifacts.bucket }
output "codedeploy_app_name"  { value = aws_codedeploy_app.main.name }
output "codedeploy_dg_name"   { value = aws_codedeploy_deployment_group.main.deployment_group_name }
output "github_connection_arn"{ value = aws_codestarconnections_connection.github.arn }
output "alert_sns_arn"        { value = aws_sns_topic.pipeline_alerts.arn }
