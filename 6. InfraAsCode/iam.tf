# Roles de serviço para os recursos aws

resource "aws_iam_role" "glue_role" {
  name = "glue-service-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name   = "glue-s3-access"
  role   = aws_iam_role.glue_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.bronze.arn}",
        "${aws_s3_bucket.bronze.arn}/*",
        "${aws_s3_bucket.silver.arn}",
        "${aws_s3_bucket.silver.arn}/*",
        "${aws_s3_bucket.gold.arn}",
        "${aws_s3_bucket.gold.arn}/*",
        "${aws_s3_bucket.landing_zone.arn}",
        "${aws_s3_bucket.landing_zone.arn}/*",
        "${aws_s3_bucket.scripts.arn}",
        "${aws_s3_bucket.scripts.arn}/*"
      ]
    }
  ]
}
EOF
}

# Additional Lake Formation permissions for Glue role
resource "aws_iam_role_policy" "glue_lakeformation" {
  name   = "glue-lakeformation-access"
  role   = aws_iam_role.glue_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lakeformation:GetDataAccess",
        "lakeformation:GrantPermissions",
        "lakeformation:RevokePermissions",
        "lakeformation:ListPermissions",
        "lakeformation:BatchGrantPermissions",
        "lakeformation:BatchRevokePermissions",
        "lakeformation:GetDataLakeSettings",
        "lakeformation:PutDataLakeSettings",
        "lakeformation:GetEffectivePermissionsForPath",
        "lakeformation:ListResources",
        "lakeformation:DescribeResource",
        "lakeformation:GetResourceLFTags",
        "lakeformation:ListLFTags",
        "lakeformation:GetLFTag",
        "lakeformation:SearchDatabasesByLFTags",
        "lakeformation:SearchTablesByLFTags",
        "lakeformation:RegisterResource",
        "lakeformation:DeregisterResource",
        "lakeformation:UpdateResource",
        "lakeformation:AddLFTagsToResource",
        "lakeformation:RemoveLFTagsFromResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketAcl",
        "s3:GetObjectAcl"
      ],
      "Resource": [
        "${aws_s3_bucket.bronze.arn}",
        "${aws_s3_bucket.bronze.arn}/*"
      ]
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "dms_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "dms_kinesis_role" {
  name               = "dms-kinesis-access"
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json
}

resource "aws_iam_role_policy" "dms_kinesis" {
  name = "dms-kinesis-policy"
  role = aws_iam_role.dms_kinesis_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:DescribeStream"
      ]
      Resource = aws_kinesis_stream.clientes_stream.arn
    }]
  })
}

# Create custom DMS VPC role with proper managed policy
resource "aws_iam_role" "dms_vpc_role" {
  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_vpc_trust.json
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "dms-vpc-management"
  }
}

data "aws_iam_policy_document" "dms_vpc_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_attach" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# Alternative: Use service-linked role (comment out the above if using this)
# resource "aws_iam_service_linked_role" "dms_vpc_role" {
#   aws_service_name = "dms.amazonaws.com"
#   description      = "Service-linked role for DMS VPC operations"
# }

resource "aws_iam_role" "firehose_role" {
  name = "firehose-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose-policy"
  role = aws_iam_role.firehose_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.bronze.arn}",
        "${aws_s3_bucket.bronze.arn}/*",
        "${aws_s3_bucket.landing_zone.arn}",
        "${aws_s3_bucket.landing_zone.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:ListShards"
      ],
      "Resource": "${aws_kinesis_stream.clientes_stream.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role" "eventbridge_role" {
  name = "eventbridge-glue-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "eventbridge_glue" {
  name = "eventbridge-glue-policy"
  role = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun"
        ]
        Resource = [
          aws_glue_job.etl_clientes_job.arn,
          aws_glue_job.etl_clientes_test_job.arn
        ]
      }
    ]
  })
} 

# Athena IAM policies
data "aws_iam_policy_document" "athena_results" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetBucketLocation",
    ]
    resources = [
      "${aws_s3_bucket.athena_results.arn}",
      "${aws_s3_bucket.athena_results.arn}/*",
    ]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetWorkGroup",
      "athena:StopQueryExecution"
    ]
    resources = [
      "arn:aws:athena:*:*:workgroup/${var.athena_workgroup_name}"
    ]
  }
}

resource "aws_iam_policy" "athena_results_s3" {
  name   = "AthenaResultsS3Access"
  policy = data.aws_iam_policy_document.athena_results.json
}

# Attach the policy to the Glue service role since it's likely to be used with Athena
resource "aws_iam_role_policy_attachment" "glue_service_athena_results" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.athena_results_s3.arn
} 

# Create an Athena query role to execute queries
resource "aws_iam_role" "athena_query_role" {
  name = "athena-query-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "athena-query-execution"
  }
}

# Glue catalog access policy for Athena role
data "aws_iam_policy_document" "glue_catalog" {
  statement {
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTableVersions",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition"
    ]
    resources = ["*"]  # Could be restricted further in production
  }
}

resource "aws_iam_policy" "glue_catalog_access" {
  name   = "GlueCatalogRead"
  policy = data.aws_iam_policy_document.glue_catalog.json
}

resource "aws_iam_role_policy_attachment" "attach_glue_catalog" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = aws_iam_policy.glue_catalog_access.arn
}

# S3 data access policy for Athena role
data "aws_iam_policy_document" "s3_data_read" {
  statement {
    effect  = "Allow"
    actions = [
      "s3:GetObject", 
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.bronze.arn,
      "${aws_s3_bucket.bronze.arn}/*",
      aws_s3_bucket.silver.arn,
      "${aws_s3_bucket.silver.arn}/*",
      aws_s3_bucket.gold.arn,
      "${aws_s3_bucket.gold.arn}/*",
      aws_s3_bucket.athena_results.arn,
      "${aws_s3_bucket.athena_results.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_data_read_access" {
  name   = "S3DataReadAccess"
  policy = data.aws_iam_policy_document.s3_data_read.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_data_read" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = aws_iam_policy.s3_data_read_access.arn
}

# Attach existing Athena results policy to the new role
resource "aws_iam_role_policy_attachment" "attach_athena_results" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = aws_iam_policy.athena_results_s3.arn
} 

# Custom Lake Formation policy for Athena role
resource "aws_iam_policy" "lake_formation_access" {
  name = "LakeFormationAccess"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GetMetadataAccess",
          "lakeformation:ListPermissions",
          "lakeformation:GetEffectivePermissionsForPath",
          "lakeformation:ListResources",
          "lakeformation:BatchDescribeResource",
          "lakeformation:DescribeResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lake_formation_custom" {
  role       = aws_iam_role.athena_query_role.name
  policy_arn = aws_iam_policy.lake_formation_access.arn
} 