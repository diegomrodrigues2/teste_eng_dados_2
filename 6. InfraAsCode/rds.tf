resource "aws_db_instance" "clientes" {
  identifier         = "clientes-db"
  engine             = "mysql"
  engine_version     = "8.0"
  instance_class     = "db.t3.medium"
  allocated_storage  = 20
  db_name            = var.db_name
  username           = var.db_username
  password           = var.db_password
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Enable binary logging for DMS CDC
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  
  # Parameter group for binary logging
  parameter_group_name = aws_db_parameter_group.mysql_binlog.name
}

resource "aws_db_parameter_group" "mysql_binlog" {
  name   = "mysql-binlog-params"
  family = "mysql8.0"

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  parameter {
    name  = "binlog_row_image"
    value = "FULL"
  }
} 