# Administrators - Include account root for initial setup
resource "aws_lakeformation_data_lake_settings" "settings" {
  admins = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
    aws_iam_role.lf_admin.arn,
    aws_iam_role.glue_role.arn,  # Existing Glue role also as admin
  ]
  
  # Enable trusted resource owners
  trusted_resource_owners = []
  
  depends_on = [
    aws_iam_role.lf_admin,
    aws_iam_role.glue_role
  ]
}

resource "aws_iam_role" "lf_admin" {
  name               = "lf-admin-role"
  assume_role_policy = data.aws_iam_policy_document.lf_admin_assume.json
  
  tags = {
    projeto = "teste_eng_dados"
    purpose = "lakeformation-admin"
  }
}

data "aws_iam_policy_document" "lf_admin_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lakeformation.amazonaws.com", "glue.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Lake Formation admin permissions
resource "aws_iam_role_policy_attachment" "lf_admin_service" {
  role       = aws_iam_role.lf_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
}

resource "aws_iam_role_policy" "lf_admin_additional" {
  name = "lf-admin-additional-permissions"
  role = aws_iam_role.lf_admin.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lakeformation:*",
          "glue:*",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data Science Role - Read access a Silver e Gold layers apenas
resource "aws_iam_role" "data_science_role" {
  name = "data-science-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
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
    purpose = "data-science"
  }
}

# Data Engineering Role - Full access para Bronze, Silver gereciamento
resource "aws_iam_role" "data_engineering_role" {
  name = "data-engineering-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
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
    purpose = "data-engineering"
  }
}

# Basic IAM permissions for Data Science role
resource "aws_iam_role_policy" "data_science_basic" {
  name = "data-science-basic-permissions"
  role = aws_iam_role.data_science_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTables"
        ]
        Resource = [
          "${aws_s3_bucket.silver.arn}",
          "${aws_s3_bucket.silver.arn}/*",
          "${aws_s3_bucket.gold.arn}",
          "${aws_s3_bucket.gold.arn}/*",
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/${aws_glue_catalog_database.datalake_db.name}",
          "arn:aws:glue:*:*:table/${aws_glue_catalog_database.datalake_db.name}/*"
        ]
      }
    ]
  })
}

# Basic IAM permissions for Data Engineering role
resource "aws_iam_role_policy" "data_engineering_basic" {
  name = "data-engineering-basic-permissions"
  role = aws_iam_role.data_engineering_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "glue:*"
        ]
        Resource = [
          "${aws_s3_bucket.bronze.arn}",
          "${aws_s3_bucket.bronze.arn}/*",
          "${aws_s3_bucket.silver.arn}",
          "${aws_s3_bucket.silver.arn}/*",
          "${aws_s3_bucket.landing_zone.arn}",
          "${aws_s3_bucket.landing_zone.arn}/*",
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/${aws_glue_catalog_database.datalake_db.name}",
          "arn:aws:glue:*:*:table/${aws_glue_catalog_database.datalake_db.name}/*"
        ]
      }
    ]
  })
}

# Register S3 locations with specific prefixes
resource "aws_lakeformation_resource" "bronze_location" {
  arn      = "${aws_s3_bucket.bronze.arn}/"
  role_arn = aws_iam_role.lf_admin.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_s3_bucket.bronze,
    aws_iam_role.lf_admin,
    null_resource.wait_for_lf_settings
  ]
}

resource "aws_lakeformation_resource" "silver_location" {
  arn      = "${aws_s3_bucket.silver.arn}/"
  role_arn = aws_iam_role.lf_admin.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_s3_bucket.silver,
    aws_iam_role.lf_admin,
    null_resource.wait_for_lf_settings
  ]
}

resource "aws_lakeformation_resource" "gold_location" {
  arn      = "${aws_s3_bucket.gold.arn}/"
  role_arn = aws_iam_role.lf_admin.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_s3_bucket.gold,
    aws_iam_role.lf_admin,
    null_resource.wait_for_lf_settings
  ]
}

resource "aws_lakeformation_resource" "landing_zone_location" {
  arn      = "${aws_s3_bucket.landing_zone.arn}/"
  role_arn = aws_iam_role.lf_admin.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_s3_bucket.landing_zone,
    aws_iam_role.lf_admin,
    null_resource.wait_for_lf_settings
  ]
}

# Add a null_resource to ensure Lake Formation resources are properly propagated
resource "null_resource" "wait_for_lakeformation" {
  depends_on = [
    aws_lakeformation_resource.bronze_location,
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_resource.gold_location,
    aws_lakeformation_resource.landing_zone_location,
    aws_lakeformation_data_lake_settings.settings
  ]
  
  provisioner "local-exec" {
    command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"Start-Sleep -Seconds 60\""
  }
}

# Wait for Lake Formation settings to propagate
resource "null_resource" "wait_for_lf_settings" {
  depends_on = [
    aws_lakeformation_data_lake_settings.settings
  ]
  
  provisioner "local-exec" {
    command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"Start-Sleep -Seconds 30\""
  }
}

# Database permissions for Lake Formation admin
resource "aws_lakeformation_permissions" "lf_admin_database" {
  principal   = aws_iam_role.lf_admin.arn
  permissions = ["ALTER", "CREATE_TABLE", "DESCRIBE", "DROP"]
  
  database {
    name = aws_glue_catalog_database.datalake_db.name
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    null_resource.wait_for_lf_settings
  ]
}

# Data Science: Database permissions (separate from table permissions)
resource "aws_lakeformation_permissions" "data_science_database" {
  principal                     = aws_iam_role.data_science_role.arn
  permissions                   = ["DESCRIBE"]
  permissions_with_grant_option = []
  
  database {
    name = aws_glue_catalog_database.datalake_db.name
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.data_science_role
  ]
}

# Data Science: Silver data location access
resource "aws_lakeformation_permissions" "data_science_silver_location" {
  principal                     = aws_iam_role.data_science_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.silver_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.data_science_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Science: Gold data location access
resource "aws_lakeformation_permissions" "data_science_gold_location" {
  principal                     = aws_iam_role.data_science_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.gold_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.gold_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.data_science_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Science: Table permissions for all tables in Silver layer
resource "aws_lakeformation_permissions" "data_science_silver_tables" {
  principal                     = aws_iam_role.data_science_role.arn
  permissions                   = ["SELECT", "DESCRIBE"]
  permissions_with_grant_option = []
  
  table {
    database_name = aws_glue_catalog_database.datalake_db.name
    wildcard      = true
  }
  
  depends_on = [
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.data_science_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Science: Read permissions on Gold view (specific table)
resource "aws_lakeformation_permissions" "data_science_gold_read" {
  principal                     = aws_iam_role.data_science_role.arn
  permissions                   = ["SELECT", "DESCRIBE"]
  permissions_with_grant_option = []
  
  table {
    database_name = aws_glue_catalog_database.datalake_db.name
    name          = aws_glue_catalog_table.gold_view.name
  }
  
  depends_on = [
    aws_lakeformation_resource.gold_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_table.gold_view,
    aws_iam_role.data_science_role,
  ]
}

# Data Engineering: Database permissions (separate from table permissions)
resource "aws_lakeformation_permissions" "data_engineering_database" {
  principal                     = aws_iam_role.data_engineering_role.arn
  permissions                   = ["CREATE_TABLE", "DROP", "ALTER"]
  permissions_with_grant_option = []
  
  database {
    name = aws_glue_catalog_database.datalake_db.name
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.data_engineering_role
  ]
}

# Data Engineering: Table permissions (separate from database permissions)
resource "aws_lakeformation_permissions" "data_engineering_tables" {
  principal                     = aws_iam_role.data_engineering_role.arn
  permissions                   = ["SELECT", "INSERT", "DESCRIBE"]
  permissions_with_grant_option = []
  
  table {
    database_name = aws_glue_catalog_database.datalake_db.name
    wildcard      = true
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.data_engineering_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Engineering: Bronze data location access
resource "aws_lakeformation_permissions" "data_engineering_bronze_location" {
  principal                     = aws_iam_role.data_engineering_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.bronze_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.bronze_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.data_engineering_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Engineering: Silver data location access
resource "aws_lakeformation_permissions" "data_engineering_silver_location" {
  principal                     = aws_iam_role.data_engineering_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.silver_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.data_engineering_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Data Engineering: Landing zone data location access
resource "aws_lakeformation_permissions" "data_engineering_landing_location" {
  principal                     = aws_iam_role.data_engineering_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.landing_zone_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.landing_zone_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.data_engineering_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Glue Service Role: Database permissions for crawlers
resource "aws_lakeformation_permissions" "glue_role_database" {
  principal                     = aws_iam_role.glue_role.arn
  permissions                   = ["CREATE_TABLE", "DROP", "ALTER"]
  permissions_with_grant_option = []
  
  database {
    name = aws_glue_catalog_database.datalake_db.name
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.glue_role
  ]
}

# Glue Service Role: Table permissions (separate from database permissions)
resource "aws_lakeformation_permissions" "glue_role_tables" {
  principal                     = aws_iam_role.glue_role.arn
  permissions                   = ["SELECT", "INSERT", "DESCRIBE"]
  permissions_with_grant_option = []
  
  table {
    database_name = aws_glue_catalog_database.datalake_db.name
    wildcard      = true
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Glue Service Role: Bronze bucket data location access
resource "aws_lakeformation_permissions" "glue_role_bronze_location" {
  principal                     = aws_iam_role.glue_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.bronze_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.bronze_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Glue Service Role: Silver bucket data location access
resource "aws_lakeformation_permissions" "glue_role_silver_location" {
  principal                     = aws_iam_role.glue_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.silver_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.silver_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Glue Service Role: Landing zone data location access
resource "aws_lakeformation_permissions" "glue_role_landing_location" {
  principal                     = aws_iam_role.glue_role.arn
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = []
  
  data_location {
    arn = aws_lakeformation_resource.landing_zone_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.landing_zone_location,
    aws_lakeformation_data_lake_settings.settings,
    aws_iam_role.glue_role,
    aws_lakeformation_permissions.lf_admin_database
  ]
}

# Register Athena results bucket as a Lake Formation resource
resource "aws_lakeformation_resource" "athena_results_location" {
  arn = "${aws_s3_bucket.athena_results.arn}/${var.athena_results_prefix}"
  
  role_arn = aws_iam_role.lf_admin.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_s3_bucket.athena_results
  ]
}

# Grant Lake Formation permissions to Athena query role for query results location
resource "aws_lakeformation_permissions" "athena_results_location_access" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]
  
  data_location {
    arn = aws_lakeformation_resource.athena_results_location.arn
  }
  
  depends_on = [
    aws_lakeformation_data_lake_settings.settings,
    aws_lakeformation_resource.athena_results_location,
    aws_iam_role.athena_query_role
  ]
}

# Grant Athena query role permissions to the bronze bucket
resource "aws_lakeformation_permissions" "athena_bronze_location" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]
  
  data_location {
    arn = aws_lakeformation_resource.bronze_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.bronze_location,
    aws_iam_role.athena_query_role
  ]
}

# Grant Athena query role permissions to the database and tables
resource "aws_lakeformation_permissions" "athena_database" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["DESCRIBE", "CREATE_TABLE", "ALTER", "DROP"]
  
  database {
    name = aws_glue_catalog_database.datalake_db.name
  }
  
  depends_on = [
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.athena_query_role
  ]
}

# Grant Athena query role table permissions
resource "aws_lakeformation_permissions" "athena_tables" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["SELECT", "DESCRIBE", "INSERT", "DELETE"]
  
  table {
    database_name = aws_glue_catalog_database.datalake_db.name
    wildcard      = true
  }
  
  depends_on = [
    aws_glue_catalog_database.datalake_db,
    aws_iam_role.athena_query_role,
    aws_lakeformation_permissions.athena_database
  ]
}

# Grant Athena query role permissions to the silver bucket
resource "aws_lakeformation_permissions" "athena_silver_location" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]
  
  data_location {
    arn = aws_lakeformation_resource.silver_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.silver_location,
    aws_iam_role.athena_query_role
  ]
}

# Grant Athena query role permissions to the gold bucket
resource "aws_lakeformation_permissions" "athena_gold_location" {
  principal   = aws_iam_role.athena_query_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]
  
  data_location {
    arn = aws_lakeformation_resource.gold_location.arn
  }
  
  depends_on = [
    aws_lakeformation_resource.gold_location,
    aws_iam_role.athena_query_role
  ]
}

