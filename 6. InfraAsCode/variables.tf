variable "db_password" {
  description = "Password for RDS MySQL instance"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!" # You should use a more secure method in production
}

variable "db_username" {
  description = "Username for RDS MySQL instance"
  type        = string
  default     = "admin"
}

variable "db_name" {
  description = "Database name for RDS MySQL instance"
  type        = string
  default     = "clientesdb"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-1"
}

variable "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
  default     = "athena-results-teste-eng-dados-2"
}

variable "athena_results_prefix" {
  description = "Prefix for Athena query results in the S3 bucket"
  type        = string
  default     = "results/"
}

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "analysis-workgroup"
} 