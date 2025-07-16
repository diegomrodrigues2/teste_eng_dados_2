# Esse bucket será responsável por receber os dados
# provindos do CDC e outras fontes streaming que geram
# múltiplos writes e possívelmente arquivos pequenos
# além de servir como camada de ingestão (landing)
resource "aws_s3_bucket" "landing_zone" {
  bucket = "bucket-landing-zone-diegorodrigues"
  tags = {
    projeto = "teste_eng_dados"
    camada  = "landing_zone"
    tipo    = "ingestao_e_streaming"
  }
}

resource "aws_s3_bucket_versioning" "landing_zone_versioning" {
  bucket = aws_s3_bucket.landing_zone.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "landing_zone_pab" {
  bucket = aws_s3_bucket.landing_zone.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cost optimization: Add lifecycle policy to expire landing zone data after processing
resource "aws_s3_bucket_lifecycle_configuration" "landing_zone_lifecycle" {
  bucket = aws_s3_bucket.landing_zone.id

  rule {
    id     = "landing_zone_cleanup"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7  # Remove data after 7 days to reduce storage costs
    }
  }
}

# Upload do CSV sintético para testes
resource "aws_s3_object" "clientes_csv" {
  bucket = aws_s3_bucket.landing_zone.id
  key    = "clientes_sinteticos.csv"
  source = "../datasets/clientes_sinteticos.csv"
  etag   = filemd5("../datasets/clientes_sinteticos.csv")
  
  tags = {
    projeto = "teste_eng_dados"
    type    = "test-data"
    purpose = "glue-job-testing"
  }
}

# Upload do CSV também com nome para test job
resource "aws_s3_object" "test_clientes_csv" {
  bucket = aws_s3_bucket.landing_zone.id
  key    = "test_clientes.csv"
  source = "../datasets/clientes_sinteticos.csv"
  etag   = filemd5("../datasets/clientes_sinteticos.csv")
  
  tags = {
    projeto = "teste_eng_dados"
    type    = "test-data"
    purpose = "glue-test-job"
  }
}

# Esse bucket armazena os dados na camada bronze (raw)
# com transformações mínimas mas já organizados
# É a primeira camada de processamento após a ingestão
resource "aws_s3_bucket" "bronze" {
  bucket = "bucket-bronze-diegorodrigues"
  tags = {
    projeto = "teste_eng_dados"
    camada  = "bronze"
  }
}

resource "aws_s3_bucket_versioning" "bronze_versioning" {
  bucket = aws_s3_bucket.bronze.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "bronze_pab" {
  bucket = aws_s3_bucket.bronze.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Esse bucket armazena os dados na camada silver (trusted)
# com dados já limpos, validados e transformados
# Contém regras de qualidade de dados aplicadas
resource "aws_s3_bucket" "silver" {
  bucket = "bucket-silver-diegorodrigues"
  tags = {
    projeto = "teste_eng_dados"
    camada  = "silver"
  }
}

resource "aws_s3_bucket_versioning" "silver_versioning" {
  bucket = aws_s3_bucket.silver.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "silver_pab" {
  bucket = aws_s3_bucket.silver.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Esse bucket armazena os dados na camada gold (curated)
# contendo dados agregados, métricas e indicadores
# prontos para consumo por aplicações de BI e Analytics
resource "aws_s3_bucket" "gold" {
  bucket = "bucket-gold-diegorodrigues"
  tags = {
    projeto = "teste_eng_dados"
    camada  = "gold"
  }
}

resource "aws_s3_bucket_versioning" "gold_versioning" {
  bucket = aws_s3_bucket.gold.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "gold_pab" {
  bucket = aws_s3_bucket.gold.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
} 

resource "aws_s3_bucket" "athena_results" {
  bucket = var.athena_results_bucket

  tags = {
    Name = "Athena Query Results"
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results_block_public_access" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
} 