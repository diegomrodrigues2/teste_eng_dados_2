# Glue Workflow to orchestrate the ETL jobs
resource "aws_glue_workflow" "etl_clientes" {
  name = "etl-clientes-workflow"
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "etl-orchestration"
  }
}

# Start trigger for the workflow (will be triggered by EventBridge)
resource "aws_glue_trigger" "start_workflow" {
  name         = "start-etl-clientes-workflow"
  type         = "ON_DEMAND"
  workflow_name = aws_glue_workflow.etl_clientes.name
  
  actions {
    job_name = aws_glue_job.etl_clientes_job.name
    arguments = {
      "--input_path"                  = "s3://${aws_s3_bucket.landing_zone.bucket}/clientes_sinteticos.csv"
      "--bronze_target_bucket_path"   = "s3://${aws_s3_bucket.bronze.bucket}/tabela_cliente_landing/"
      "--silver_target_bucket_path"   = "s3://${aws_s3_bucket.silver.bucket}/tb_cliente/"
    }
  }
  
  depends_on = [aws_glue_job.etl_clientes_job]
}

# Cria-se o catalog acessível no Athena
resource "aws_glue_catalog_database" "datalake_db" {
  name = "medallion_datalake"
}

# O crawler será responsável por ler os dados da camada bronze
resource "aws_glue_crawler" "bronze_crawler" {
  name          = "crawler_bronze"
  database_name = aws_glue_catalog_database.datalake_db.name
  role          = aws_iam_role.glue_role.arn
  
  s3_target {
    path = "s3://${aws_s3_bucket.bronze.bucket}/"
  }
  
  # Lake Formation configuration
  lake_formation_configuration {
    use_lake_formation_credentials = true
    account_id                     = data.aws_caller_identity.current.account_id
  }
  
  # Schema change policy to handle updates
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
  
  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
  
  depends_on = [
    aws_s3_bucket.bronze,
    aws_lakeformation_resource.bronze_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.glue_role_database,
    aws_lakeformation_permissions.glue_role_bronze_location
  ]
}

# E esse responsável por ler da camada silver
resource "aws_glue_crawler" "silver_crawler" {
  name          = "crawler_silver"
  database_name = aws_glue_catalog_database.datalake_db.name
  role          = aws_iam_role.glue_role.arn
  
  s3_target {
    path = "s3://${aws_s3_bucket.silver.bucket}/"
  }
  
  # Lake Formation configuration
  lake_formation_configuration {
    use_lake_formation_credentials = true
    account_id                    = data.aws_caller_identity.current.account_id
  }
  
  # Schema change policy to handle updates
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
  
  depends_on = [
    aws_s3_bucket.silver,
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.glue_role_database,
    aws_lakeformation_permissions.glue_role_silver_location
  ]
}

# Mesmo job será responsável em escrever na bronze e na silver
# Para fins didáticos, dependendo da complexidado da malha talvez
# uma separação seja necessária.
resource "aws_glue_job" "etl_clientes_job" {
  name       = "etl_clientes_bronze_silver"
  role_arn   = aws_iam_role.glue_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/etl_clientes_bronze_and_silver.py"
    python_version  = "3"
  }
  
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2  # Reduced from 5 to 2 workers to save costs
  timeout           = 60  # 60 minutes timeout
  
  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "false"  # Disabled continuous logging to reduce CloudWatch costs
    "--enable-metrics"                   = "false"  # Disabled metrics to reduce costs
    "--enable-spark-ui"                  = "false"  # Disabled Spark UI to reduce costs
    "--spark-event-logs-path"           = "s3://${aws_s3_bucket.scripts.bucket}/spark-logs/"
    "--job-bookmark-option"             = "job-bookmark-enable"
    "--TempDir"                         = "s3://${aws_s3_bucket.scripts.bucket}/temp/"
  }
  
  execution_property {
    max_concurrent_runs = 1
  }
  
  tags = {
    projeto = "teste_eng_dados"
    camada  = "bronze_silver"
    environment = "production"
  }
}

# Um job de tests que lê direto do csv
resource "aws_glue_job" "etl_clientes_test_job" {
  name       = "etl_clientes_bronze_silver_test"
  role_arn   = aws_iam_role.glue_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/etl_clientes_bronze_and_silver.py"
    python_version  = "3"
  }
  
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 60
  
  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"   # Enable logging for testing
    "--enable-metrics"                   = "true"   # Enable metrics for testing
    "--enable-spark-ui"                  = "true"   # Enable Spark UI for debugging
    "--spark-event-logs-path"           = "s3://${aws_s3_bucket.scripts.bucket}/spark-logs/"
    "--job-bookmark-option"             = "job-bookmark-disable"  # Disable bookmark for testing
    "--TempDir"                         = "s3://${aws_s3_bucket.scripts.bucket}/temp/"
    # Default test parameters - can be overridden when running
    "--input_path"                      = "s3://${aws_s3_bucket.landing_zone.bucket}/test_clientes.csv"
    "--bronze_target_bucket_path"       = "s3://${aws_s3_bucket.bronze.bucket}/test_tabela_cliente_landing/"
    "--silver_target_bucket_path"       = "s3://${aws_s3_bucket.silver.bucket}/test_tb_cliente/"
  }
  
  execution_property {
    max_concurrent_runs = 1
  }
  
  tags = {
    projeto = "teste_eng_dados"
    camada  = "bronze_silver"
    environment = "test"
  }
}

# S3 bucket para armazenar os scripts
resource "aws_s3_bucket" "scripts" {
  bucket = "bucket-scripts-diegorodrigues"
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "glue-scripts"
  }
}

resource "aws_s3_bucket_versioning" "scripts_versioning" {
  bucket = aws_s3_bucket.scripts.id
  versioning_configuration {
    status = "Disabled"  # Disabled versioning to reduce storage costs
  }
}

# Faz o upload do ETL script para o bucket S3
resource "aws_s3_object" "etl_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "etl_clientes_bronze_and_silver.py"
  source = "../1. ETL/etl_clientes_bronze_and_silver.py"
  etag   = filemd5("../1. ETL/etl_clientes_bronze_and_silver.py")
  
  tags = {
    projeto = "teste_eng_dados"
    type    = "glue-script"
  }
}



# View virtual que lê os dados da silver e deixa disponível para
# usuários finais
resource "aws_glue_catalog_table" "gold_view" {
  name          = "gold_view"
  database_name = aws_glue_catalog_database.datalake_db.name
  table_type    = "VIRTUAL_VIEW"
  parameters = {
    presto_view = "true"
  }
  
  view_original_text = jsonencode(
    {
      originalSql = "SELECT cod_cliente, nm_cliente, nm_pais_cliente, nm_cidade_cliente, nm_rua_cliente, num_casa_cliente, num_telefone_cliente, dt_nascimento_cliente, dt_atualizacao, tp_pessoa, vl_renda FROM \"${aws_glue_catalog_database.datalake_db.name}\".\"tb_cliente\""
      queryType = "SQL"
    }
  )
  
  storage_descriptor {
    columns {
      name = "cod_cliente"
      type = "int"
    }
    columns {
      name = "nm_cliente"
      type = "string"
    }
    columns {
      name = "nm_pais_cliente"
      type = "string"
    }
    columns {
      name = "nm_cidade_cliente"
      type = "string"
    }
    columns {
      name = "nm_rua_cliente"
      type = "string"
    }
    columns {
      name = "num_casa_cliente"
      type = "int"
    }
    columns {
      name = "num_telefone_cliente"
      type = "string"
    }
    columns {
      name = "dt_nascimento_cliente"
      type = "date"
    }
    columns {
      name = "dt_atualizacao"
      type = "date"
    }
    columns {
      name = "tp_pessoa"
      type = "string"
    }
    columns {
      name = "vl_renda"
      type = "double"
    }
  }
} 