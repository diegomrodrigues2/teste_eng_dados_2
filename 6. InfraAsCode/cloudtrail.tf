# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "audit_logs" {
  bucket = "bucket-audit-logs-diegorodrigues"
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "audit-logs"
  }
}

# Removi os cloud trail logs para reduzir custos
resource "aws_s3_bucket_versioning" "audit_logs_versioning" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Removi os cloud trail logs para reduzir custos
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs_lifecycle" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "audit_logs_retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1  # Reduzi o tempo de retenção para reduzir customs
    }
  }
}

# CloudTrail bucket policy
resource "aws_s3_bucket_policy" "audit_logs_policy" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Mesma coisa, reduzindo custos de cloud trail do Lakeformation
resource "aws_cloudtrail" "lakeformation_trail" {
  name                          = "lakeformation-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.bucket
  include_global_service_events = false  # Reduced scope to minimize data volume
  is_multi_region_trail         = false  # Single-region trail to reduce costs
  enable_log_file_validation    = false  # Disabled validation to reduce processing costs
  enable_logging                = false  # DISABLED - CloudTrail monitoring is turned off
  
  # Minimal event selector configuration
  event_selector {
    read_write_type           = "WriteOnly"  # Only capture write events to reduce volume
    include_management_events = true
    
    # Monitor critical data locations only
    data_resource {
      type   = "AWS::S3::Object"
      values = [
        "${aws_s3_bucket.bronze.arn}/*",
        "${aws_s3_bucket.silver.arn}/*"
      ]
    }
  }
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "lakeformation-audit-minimal"
  }
  
  depends_on = [
    aws_s3_bucket_policy.audit_logs_policy,
    aws_lakeformation_data_lake_settings.settings
  ]
}