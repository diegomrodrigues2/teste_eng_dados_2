provider "aws" {
  shared_credentials_files = [".aws/credentials"]
  shared_config_files      = [".aws/config"]
  region                   = "us-west-1"
}

# Data sources for current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Load all modules 