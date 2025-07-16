# Job schedulado para rodar no EOD dado que estamos lidando com uma
# dimensão apenas. Para dados mais "quentes" talvez um schedule mais
# curto ou até mesmo um job streaming seria mais adequado.
resource "aws_cloudwatch_event_rule" "schedule_glue" {
  name                = "schedule-glue-jobs"
  schedule_expression = "cron(0 22 * * ? *)" # Daily at 22:00 UTC (EOD)
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "eod-scheduling"
  }
}

# IAM role for EventBridge to invoke Glue workflows
resource "aws_iam_role" "eb_invoke_glue" {
  name = "eventbridge-invoke-glue-workflow"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "eventbridge-glue-workflow"
  }
}

# IAM policy for EventBridge to start Glue workflows
resource "aws_iam_role_policy" "eb_glue_workflow_permissions" {
  role   = aws_iam_role.eb_invoke_glue.id
  name   = "EventBridgeGlueWorkflowPolicy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["glue:StartWorkflowRun"]
      Resource = [aws_glue_workflow.etl_clientes.arn]
    }]
  })
}

# EventBridge target pointing to Glue workflow instead of job directly
resource "aws_cloudwatch_event_target" "target_etl_workflow" {
  rule      = aws_cloudwatch_event_rule.schedule_glue.name
  target_id = "etl-clients-workflow"
  arn       = aws_glue_workflow.etl_clientes.arn
  role_arn  = aws_iam_role.eb_invoke_glue.arn
  
  depends_on = [
    aws_glue_workflow.etl_clientes,
    aws_iam_role.eb_invoke_glue
  ]
} 