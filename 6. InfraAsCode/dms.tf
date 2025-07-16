resource "aws_dms_replication_instance" "cdc" {
  replication_instance_id   = "dms-cdc-instance"
  replication_instance_class = "dms.t3.medium"
  allocated_storage          = 50
  publicly_accessible        = false
  vpc_security_group_ids     = [aws_security_group.dms_sg.id]
  
  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_attach
  ]
}

resource "aws_dms_endpoint" "source_mysql" {
  endpoint_id   = "mysql-source"
  endpoint_type = "source"
  engine_name   = "mysql"

  username       = var.db_username
  password       = var.db_password
  server_name    = aws_db_instance.clientes.address
  port           = aws_db_instance.clientes.port
  database_name  = var.db_name

  extra_connection_attributes = "serverTimezone=UTC"
}

resource "aws_dms_endpoint" "target_kinesis" {
  endpoint_id   = "kinesis-target"
  endpoint_type = "target"
  engine_name   = "kinesis"

  kinesis_settings {
    stream_arn             = aws_kinesis_stream.clientes_stream.arn
    service_access_role_arn = aws_iam_role.dms_kinesis_role.arn
  }
}

resource "aws_dms_replication_task" "mysql_to_kinesis" {
  replication_task_id          = "mysql-to-kinesis"
  replication_instance_arn     = aws_dms_replication_instance.cdc.replication_instance_arn
  source_endpoint_arn          = aws_dms_endpoint.source_mysql.endpoint_arn
  target_endpoint_arn          = aws_dms_endpoint.target_kinesis.endpoint_arn
  migration_type               = "cdc"
  table_mappings               = file("${path.module}/config/table-mappings.json")
  replication_task_settings    = file("${path.module}/config/task-settings.json")
  
  depends_on = [
    aws_dms_endpoint.source_mysql,
    aws_dms_endpoint.target_kinesis
  ]
} 