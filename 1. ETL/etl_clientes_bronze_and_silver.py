import sys
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DateType, DoubleType
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job


def define_schema():
    """
    Define the schema for the customer data.
    
    Returns:
        StructType: The schema definition for the CSV file
    """
    return StructType([
        StructField("cod_cliente", IntegerType(), True),
        StructField("nm_cliente", StringType(), True),
        StructField("nm_pais_cliente", StringType(), True),
        StructField("nm_cidade_cliente", StringType(), True),
        StructField("nm_rua_cliente", StringType(), True),
        StructField("num_casa_cliente", IntegerType(), True),
        StructField("telefone_cliente", StringType(), True),
        StructField("dt_nascimento_cliente", DateType(), True),
        StructField("dt_atualizacao", DateType(), True),
        StructField("tp_pessoa", StringType(), True),
        StructField("vl_renda", DoubleType(), True)
    ])


def read_csv_data(spark, input_path, schema):
    """
    Read CSV data from the specified path using the provided schema.
    
    Args:
        spark: SparkSession instance
        input_path (str): Path to the CSV file
        schema (StructType): Schema definition for the CSV file
    
    Returns:
        DataFrame: Raw dataframe with the CSV data
    """
    return spark.read.csv(input_path, schema=schema, header=True)


def process_bronze_layer(df):
    """
    Process the raw data to create the bronze layer.
    
    Args:
        df: Raw dataframe
    
    Returns:
        DataFrame: Processed dataframe for bronze layer
    """
    return (
        df.withColumn("nm_cliente", F.upper(F.col("nm_cliente")))
        .withColumnRenamed("telefone_cliente", "num_telefone_cliente")
    )


def process_silver_layer(bronze_df):
    """
    Process the bronze layer data to create the silver layer.
    
    Args:
        bronze_df: Bronze layer dataframe
    
    Returns:
        DataFrame: Processed dataframe for silver layer
    """
    window_spec = Window.partitionBy("cod_cliente").orderBy(F.col("dt_atualizacao").desc())
    
    return (
        bronze_df.withColumn(
            "num_telefone_cliente",
            F.when(
                F.col("num_telefone_cliente").rlike(r"^\(\d{2}\)\d{5}-\d{4}$"),
                F.col("num_telefone_cliente")
            ).otherwise(None)
        )
        .withColumn("row_number", F.row_number().over(window_spec))
        .filter(F.col("row_number") == 1)
        .drop("row_number")
    )


def write_to_s3(df, path, format="parquet", mode="overwrite", partition_by=None):
    """
    Write dataframe to S3 in the specified format with optional partitioning.
    
    Args:
        df: Dataframe to write
        path (str): S3 path to write to
        format (str): File format (default: parquet)
        mode (str): Write mode (default: overwrite)
        partition_by (str): Column name to partition by
    """
    writer = df.write.mode(mode).format(format)
    if partition_by:
        writer = writer.partitionBy(partition_by)
    writer.save(path)

def add_processing_date(df):
    """
    Add processing date column for partitioning.
    
    Args:
        df: Input dataframe
        
    Returns:
        DataFrame: Dataframe with anomesdia column
    """
    return df.withColumn("anomesdia", F.date_format(F.current_date(), "yyyyMMdd"))

def main(args):
    """
    Main ETL function that orchestrates the entire process.
    
    Args:
        args (dict): Dictionary containing:
            - input_path: Path to the input CSV file
            - bronze_target_bucket_path: S3 path for bronze layer output
            - silver_target_bucket_path: S3 path for silver layer output
    """
    # Initialize Spark session (for local testing)
    spark = SparkSession.builder.appName("ETL_Clientes").getOrCreate()
    
    # Initialize Glue context (for Glue job execution)
    glue_context = GlueContext(spark.sparkContext)
    
    # Define schema
    schema = define_schema()
    
    # Read raw data
    raw_df = read_csv_data(spark, args['input_path'], schema)
    
    # Process bronze layer
    bronze_df = process_bronze_layer(raw_df)
    bronze_df = add_processing_date(bronze_df)  # Adicionar data de processamento
    
    # Write bronze layer to S3 with partitioning
    write_to_s3(bronze_df, args['bronze_target_bucket_path'], partition_by="anomesdia")
    
    # Process silver layer
    silver_df = process_silver_layer(bronze_df)
    silver_df = add_processing_date(silver_df)  # Adicionar data de processamento
    
    # Write silver layer to S3 with partitioning
    write_to_s3(silver_df, args['silver_target_bucket_path'], partition_by="anomesdia")
    
    print(f"ETL process completed successfully!")
    print(f"Bronze layer written to: {args['bronze_target_bucket_path']}")
    print(f"Silver layer written to: {args['silver_target_bucket_path']}")


if __name__ == "__main__":
    # For AWS Glue job execution
    if '--JOB_NAME' in sys.argv:
        # This is running as a Glue job
        args = getResolvedOptions(sys.argv, [
            'JOB_NAME',
            'input_path',
            'bronze_target_bucket_path',
            'silver_target_bucket_path'
        ])
        
        # Initialize Glue job
        glue_context = GlueContext(SparkSession.builder.getOrCreate().sparkContext)
        job = Job(glue_context)
        job.init(args['JOB_NAME'], args)
        
        # Run main function
        main(args)
        
        # Commit the job
        job.commit()
