# O Kinesis serve de ponto de entrada para os dados em tempo real
# vindos do CDC conectado o banco MySQL. Esses dados são então 
# passados via Firehouse para uma tabela na landing zone.

resource "aws_kinesis_stream" "clientes_stream" {
  name        = "clientes-stream"
  shard_count = 1
}

# Firehose to landing_zone bucket for streaming data
resource "aws_kinesis_firehose_delivery_stream" "to_landing_zone" {
  name        = "landing-zone-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.clientes_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    bucket_arn = aws_s3_bucket.landing_zone.arn
    prefix     = "raw/"
    role_arn   = aws_iam_role.firehose_role.arn
    buffering_size     = 64
    buffering_interval = 60
  }
} 