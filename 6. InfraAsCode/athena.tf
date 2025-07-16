resource "aws_athena_workgroup" "analysis" {
  name = var.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/${var.athena_results_prefix}"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "data-analysis"
  }
} 

# Grant permissions to run Athena queries
resource "aws_iam_policy" "athena_query_execution" {
  name   = "AthenaQueryExecution"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:StopQueryExecution",
        "athena:GetWorkGroup"
      ]
      Resource = aws_athena_workgroup.analysis.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_athena_execution" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = aws_iam_policy.athena_query_execution.arn
} 

# Try using AmazonLakeFormationDataAdmin instead
resource "aws_iam_role_policy_attachment" "attach_lake_formation_data_access" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
  count      = 1
}

# Attach Athena Full Access policy
resource "aws_iam_role_policy_attachment" "attach_athena_full_access" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
} 