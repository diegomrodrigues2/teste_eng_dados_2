# S3 Bucket outputs
output "bronze_bucket_name" {
  description = "Name of the Bronze S3 bucket"
  value       = aws_s3_bucket.bronze.bucket
}

output "silver_bucket_name" {
  description = "Name of the Silver S3 bucket"
  value       = aws_s3_bucket.silver.bucket
}

output "gold_bucket_name" {
  description = "Name of the Gold S3 bucket"
  value       = aws_s3_bucket.gold.bucket
}

output "landing_zone_bucket_name" {
  description = "Name of the Landing Zone S3 bucket"
  value       = aws_s3_bucket.landing_zone.bucket
}

output "scripts_bucket_name" {
  description = "Name of the Scripts S3 bucket"
  value       = aws_s3_bucket.scripts.bucket
}

output "audit_logs_bucket_name" {
  description = "Name of the Audit Logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.bucket
}

# Glue outputs
output "glue_database_name" {
  description = "Name of the Glue Catalog database"
  value       = aws_glue_catalog_database.datalake_db.name
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.etl_clientes_job.name
}

# Lake Formation outputs
output "lakeformation_admin_role_arn" {
  description = "ARN of the Lake Formation admin role"
  value       = aws_iam_role.lf_admin.arn
}

output "data_science_role_arn" {
  description = "ARN of the Data Science role"
  value       = aws_iam_role.data_science_role.arn
}

output "data_engineering_role_arn" {
  description = "ARN of the Data Engineering role"
  value       = aws_iam_role.data_engineering_role.arn
}

output "lakeformation_registered_resources" {
  description = "List of S3 buckets registered with Lake Formation"
  value = [
    aws_lakeformation_resource.bronze_location.arn,
    aws_lakeformation_resource.silver_location.arn,
    aws_lakeformation_resource.gold_location.arn,
    aws_lakeformation_resource.landing_zone_location.arn
  ]
}

# Kinesis outputs
output "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  value       = aws_kinesis_stream.clientes_stream.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  value       = aws_kinesis_stream.clientes_stream.arn
}

# DMS outputs
output "dms_replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.cdc.replication_instance_arn
}

output "dms_replication_task_arn" {
  description = "ARN of the DMS replication task"
  value       = aws_dms_replication_task.mysql_to_kinesis.replication_task_arn
}

# RDS outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.clientes.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.clientes.port
}

# EventBridge outputs
output "eventbridge_rule_name" {
  description = "Names of the EventBridge rules for ETL triggers"
  value       = [
    aws_cloudwatch_event_rule.schedule_glue.name
  ]
}

# Region information
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
} 