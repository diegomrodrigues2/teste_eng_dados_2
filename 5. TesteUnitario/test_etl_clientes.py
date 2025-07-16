import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os
from datetime import datetime, date

# Add parent directory to path to import the ETL module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '1. ETL'))

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DateType, DoubleType
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Import the functions to test
from etl_clientes_bronze_and_silver import (
    define_schema,
    read_csv_data,
    process_bronze_layer,
    process_silver_layer,
    write_to_s3,
    main
)

# Helper function to create sample data
def create_sample_raw_df(spark_session):
    """Create a sample raw dataframe for testing"""
    test_data = [
        (1, "joão silva", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999", 
            date(1990, 1, 1), date(2023, 1, 1), "PF", 5000.0),
        (2, "maria santos", "Brasil", "Rio de Janeiro", "Rua B", 456, "(21)88888-8888", 
            date(1985, 5, 15), date(2023, 1, 2), "PF", 7000.0)
    ]
    schema = define_schema()
    return spark_session.createDataFrame(test_data, schema)

def test_define_schema():
    """Test that the schema is correctly defined"""
    schema = define_schema()
    
    # Check that it returns a StructType
    assert isinstance(schema, StructType)
    
    # Check that all expected fields are present
    field_names = [field.name for field in schema.fields]
    expected_fields = [
        "cod_cliente", "nm_cliente", "nm_pais_cliente", "nm_cidade_cliente",
        "nm_rua_cliente", "num_casa_cliente", "telefone_cliente", 
        "dt_nascimento_cliente", "dt_atualizacao", "tp_pessoa", "vl_renda"
    ]
    
    for field in expected_fields:
        assert field in field_names
    
    # Check specific field types
    assert schema["cod_cliente"].dataType == IntegerType()
    assert schema["nm_cliente"].dataType == StringType()
    assert schema["dt_nascimento_cliente"].dataType == DateType()
    assert schema["vl_renda"].dataType == DoubleType()

def test_read_csv_data():
    """Test reading CSV data with mocked Spark session"""
    # Create a mock schema
    schema = define_schema()
    
    # Mock the spark.read.csv method
    mock_df = Mock()
    mock_spark = Mock()
    mock_spark.read.csv.return_value = mock_df
    
    # Call the function
    result = read_csv_data(mock_spark, "test_path.csv", schema)
    
    # Verify the spark.read.csv was called with correct parameters
    mock_spark.read.csv.assert_called_once_with("test_path.csv", schema=schema, header=True)
    
    # Verify the result is the mocked dataframe
    assert result == mock_df

def test_process_bronze_layer(spark_session):
    """Test bronze layer processing"""
    # Create test dataframe
    df = create_sample_raw_df(spark_session)
    
    # Process bronze layer
    bronze_df = process_bronze_layer(df)
    
    # Collect results
    results = bronze_df.collect()
    
    # Check that names are uppercased
    assert results[0]['nm_cliente'] == "JOÃO SILVA"
    assert results[1]['nm_cliente'] == "MARIA SANTOS"
    
    # Check that telefone_cliente was renamed to num_telefone_cliente
    assert 'num_telefone_cliente' in bronze_df.columns
    assert 'telefone_cliente' not in bronze_df.columns
    
    # Check that phone numbers are preserved
    assert results[0]['num_telefone_cliente'] == "(11)99999-9999"
    assert results[1]['num_telefone_cliente'] == "(21)88888-8888"

def test_process_silver_layer(spark_session):
    """Test silver layer processing"""
    # Create test data with duplicates and invalid phone numbers
    test_data = [
        (1, "JOÃO SILVA", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999", 
            date(1990, 1, 1), date(2023, 1, 1), "PF", 5000.0),
        (1, "JOÃO SILVA", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999", 
            date(1990, 1, 1), date(2023, 1, 2), "PF", 5500.0),  # More recent
        (2, "MARIA SANTOS", "Brasil", "Rio de Janeiro", "Rua B", 456, "invalid_phone", 
            date(1985, 5, 15), date(2023, 1, 2), "PF", 7000.0),  # Invalid phone
        (3, "CARLOS LIMA", "Brasil", "Belo Horizonte", "Rua C", 789, "(31)77777-7777", 
            date(1992, 3, 10), date(2023, 1, 3), "PF", 6000.0)
    ]
    
    # Create bronze dataframe (without telefone_cliente column)
    bronze_schema = StructType([
        StructField("cod_cliente", IntegerType(), True),
        StructField("nm_cliente", StringType(), True),
        StructField("nm_pais_cliente", StringType(), True),
        StructField("nm_cidade_cliente", StringType(), True),
        StructField("nm_rua_cliente", StringType(), True),
        StructField("num_casa_cliente", IntegerType(), True),
        StructField("num_telefone_cliente", StringType(), True),
        StructField("dt_nascimento_cliente", DateType(), True),
        StructField("dt_atualizacao", DateType(), True),
        StructField("tp_pessoa", StringType(), True),
        StructField("vl_renda", DoubleType(), True)
    ])
    
    bronze_df = spark_session.createDataFrame(test_data, bronze_schema)
    
    # Process silver layer
    silver_df = process_silver_layer(bronze_df)
    
    # Collect results
    results = silver_df.collect()
    
    # Should have 3 unique customers (deduplication worked)
    assert len(results) == 3
    
    # Check that the most recent record for customer 1 was kept
    customer_1 = [r for r in results if r['cod_cliente'] == 1][0]
    assert customer_1['vl_renda'] == 5500.0  # More recent record
    
    # Check that invalid phone number was set to None
    customer_2 = [r for r in results if r['cod_cliente'] == 2][0]
    assert customer_2['num_telefone_cliente'] is None
    
    # Check that valid phone number was preserved
    customer_3 = [r for r in results if r['cod_cliente'] == 3][0]
    assert customer_3['num_telefone_cliente'] == "(31)77777-7777"

def test_process_silver_layer_phone_validation(spark_session):
    """Test phone number validation in silver layer"""
    test_data = [
        (1, "JOÃO SILVA", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999", 
            date(1990, 1, 1), date(2023, 1, 1), "PF", 5000.0),  # Valid
        (2, "MARIA SANTOS", "Brasil", "Rio de Janeiro", "Rua B", 456, "11999999999", 
            date(1985, 5, 15), date(2023, 1, 2), "PF", 7000.0),  # Invalid format
        (3, "CARLOS LIMA", "Brasil", "Belo Horizonte", "Rua C", 789, "(31)7777-7777", 
            date(1992, 3, 10), date(2023, 1, 3), "PF", 6000.0),  # Invalid format
        (4, "ANA COSTA", "Brasil", "Salvador", "Rua D", 321, "(71)88888-8888", 
            date(1988, 7, 20), date(2023, 1, 4), "PF", 4500.0)  # Valid
    ]
    
    bronze_schema = StructType([
        StructField("cod_cliente", IntegerType(), True),
        StructField("nm_cliente", StringType(), True),
        StructField("nm_pais_cliente", StringType(), True),
        StructField("nm_cidade_cliente", StringType(), True),
        StructField("nm_rua_cliente", StringType(), True),
        StructField("num_casa_cliente", IntegerType(), True),
        StructField("num_telefone_cliente", StringType(), True),
        StructField("dt_nascimento_cliente", DateType(), True),
        StructField("dt_atualizacao", DateType(), True),
        StructField("tp_pessoa", StringType(), True),
        StructField("vl_renda", DoubleType(), True)
    ])
    
    bronze_df = spark_session.createDataFrame(test_data, bronze_schema)
    silver_df = process_silver_layer(bronze_df)
    results = silver_df.collect()
    
    # Check phone validation results
    customer_1 = [r for r in results if r['cod_cliente'] == 1][0]
    customer_2 = [r for r in results if r['cod_cliente'] == 2][0]
    customer_3 = [r for r in results if r['cod_cliente'] == 3][0]
    customer_4 = [r for r in results if r['cod_cliente'] == 4][0]
    
    # Valid phone numbers should be preserved
    assert customer_1['num_telefone_cliente'] == "(11)99999-9999"
    assert customer_4['num_telefone_cliente'] == "(71)88888-8888"
    
    # Invalid phone numbers should be set to None
    assert customer_2['num_telefone_cliente'] is None
    assert customer_3['num_telefone_cliente'] is None

def test_write_to_s3():
    """Test write_to_s3 function"""
    # Create mock dataframe
    mock_df = Mock()
    mock_writer = Mock()
    mock_writer_format = Mock()
    mock_writer_mode = Mock()
    mock_df.write = mock_writer
    mock_writer.mode.return_value = mock_writer_mode
    mock_writer_mode.format.return_value = mock_writer_format
    
    # Test basic write
    write_to_s3(mock_df, "s3://test-bucket/path")
    
    # Check correct calls were made
    mock_writer.mode.assert_called_with("overwrite")
    mock_writer_mode.format.assert_called_with("parquet")
    mock_writer_format.save.assert_called_with("s3://test-bucket/path")

@patch('etl_clientes_bronze_and_silver.write_to_s3')
@patch('etl_clientes_bronze_and_silver.GlueContext')
@patch('etl_clientes_bronze_and_silver.SparkSession')
def test_main_function(mock_spark_session, mock_glue_context, mock_write_to_s3):
    """Test main function with mocks"""
    # Create mocks
    mock_spark = Mock()
    mock_spark_context = Mock()
    mock_df = Mock()
    mock_bronze_df = Mock()
    mock_silver_df = Mock()
    
    # Configure mocks
    mock_spark_session.builder.appName.return_value.getOrCreate.return_value = mock_spark
    mock_spark.sparkContext = mock_spark_context
    mock_spark.read.csv.return_value = mock_df
    
    # Mock transformations
    with patch('etl_clientes_bronze_and_silver.process_bronze_layer', return_value=mock_bronze_df), \
         patch('etl_clientes_bronze_and_silver.process_silver_layer', return_value=mock_silver_df), \
         patch('etl_clientes_bronze_and_silver.add_processing_date', side_effect=lambda df: df):
        
        # Call the function
        args = {
            'input_path': 'test.csv',
            'bronze_target_bucket_path': 's3://bronze/path',
            'silver_target_bucket_path': 's3://silver/path'
        }
        main(args)
        
        # Verify calls
        mock_spark_session.builder.appName.assert_called_with("ETL_Clientes")
        mock_glue_context.assert_called_with(mock_spark_context)
        
        # Check write_to_s3 calls
        assert mock_write_to_s3.call_count == 2
        mock_write_to_s3.assert_any_call(mock_bronze_df, 's3://bronze/path', partition_by="anomesdia")
        mock_write_to_s3.assert_any_call(mock_silver_df, 's3://silver/path', partition_by="anomesdia")

# Integration Tests
@pytest.mark.integration
def test_complete_etl_pipeline(spark_session, tmpdir):
    """Test the complete ETL pipeline with real Spark session"""
    # Create a test CSV file
    from csv import writer
    from datetime import date
    
    test_file = tmpdir.join("test_data.csv")
    with open(test_file, 'w', newline='') as f:
        csv_writer = writer(f)
        # Write header
        csv_writer.writerow([
            "cod_cliente", "nm_cliente", "nm_pais_cliente", "nm_cidade_cliente",
            "nm_rua_cliente", "num_casa_cliente", "telefone_cliente",
            "dt_nascimento_cliente", "dt_atualizacao", "tp_pessoa", "vl_renda"
        ])
        # Write data
        csv_writer.writerow([
            1, "joão silva", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999",
            date(1990, 1, 1).isoformat(), date(2023, 1, 1).isoformat(), "PF", 5000.0
        ])
        csv_writer.writerow([
            2, "maria santos", "Brasil", "Rio de Janeiro", "Rua B", 456, "invalid_phone",
            date(1985, 5, 15).isoformat(), date(2023, 1, 2).isoformat(), "PF", 7000.0
        ])
    
    # Setup output directories
    bronze_path = str(tmpdir.join("bronze"))
    silver_path = str(tmpdir.join("silver"))
    
    # Create arguments
    args = {
        'input_path': str(test_file),
        'bronze_target_bucket_path': bronze_path,
        'silver_target_bucket_path': silver_path
    }
    
    # Mock write_to_s3 to avoid S3 dependencies
    with patch('etl_clientes_bronze_and_silver.write_to_s3') as mock_write:
        # Run the pipeline
        main(args)
        
        # Verify write_to_s3 was called with correct dataframes
        calls = mock_write.call_args_list
        assert len(calls) == 2
        
        # Get the dataframes that would have been written
        bronze_df = calls[0][0][0]
        silver_df = calls[1][0][0]
        
        # Verify transformations
        assert bronze_df.count() == 2
        assert silver_df.count() == 2
        
        # Verify bronze transformation (uppercase names)
        bronze_results = bronze_df.collect()
        assert bronze_results[0]['nm_cliente'] == "JOÃO SILVA"
        assert bronze_results[1]['nm_cliente'] == "MARIA SANTOS"
        
        # Verify silver transformation (phone validation)
        silver_results = silver_df.collect()
        customer_1 = [r for r in silver_results if r['cod_cliente'] == 1][0]
        customer_2 = [r for r in silver_results if r['cod_cliente'] == 2][0]
        assert customer_1['num_telefone_cliente'] == "(11)99999-9999"
        assert customer_2['num_telefone_cliente'] is None 