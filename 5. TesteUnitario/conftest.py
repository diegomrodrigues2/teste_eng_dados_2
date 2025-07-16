import os
import sys
import pytest
from unittest.mock import patch, MagicMock

# Ensure local Spark execution
os.environ.setdefault("SPARK_MASTER", "local[*]")
for var in ("SPARK_CONNECT_MODE_ENABLED", "SPARK_REMOTE", "SPARK_LOCAL_REMOTE", "DATABRICKS_CONNECT"):
    os.environ.pop(var, None)

# Mock AWS Glue modules before any imports
sys.modules['awsglue'] = MagicMock()
sys.modules['awsglue.utils'] = MagicMock()
sys.modules['awsglue.context'] = MagicMock()
sys.modules['awsglue.job'] = MagicMock()

# Add the ETL module to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '1. ETL'))

@pytest.fixture(scope="function")
def mock_glue_context():
    """Mock GlueContext for testing"""
    with patch('etl_clientes_bronze_and_silver.GlueContext') as mock_context:
        yield mock_context

@pytest.fixture(scope="function")
def mock_s3_write():
    """Mock S3 write operations"""
    with patch('etl_clientes_bronze_and_silver.write_to_s3') as mock_write:
        yield mock_write


@pytest.fixture(scope="function")
def sample_test_data():
    """Provide sample test data for testing"""
    from datetime import date
    
    return [
        (1, "joão silva", "Brasil", "São Paulo", "Rua A", 123, "(11)99999-9999", 
         date(1990, 1, 1), date(2023, 1, 1), "PF", 5000.0),
        (2, "maria santos", "Brasil", "Rio de Janeiro", "Rua B", 456, "(21)88888-8888", 
         date(1985, 5, 15), date(2023, 1, 2), "PF", 7000.0),
        (3, "carlos lima", "Brasil", "Belo Horizonte", "Rua C", 789, "invalid_phone", 
         date(1992, 3, 10), date(2023, 1, 3), "PF", 6000.0)
    ]


@pytest.fixture(scope="function")
def test_args():
    """Provide test arguments for main function"""
    return {
        'input_path': 'test_input.csv',
        'bronze_target_bucket_path': 's3://test-bronze/path',
        'silver_target_bucket_path': 's3://test-silver/path'
    }


# Configure pytest to handle warnings
def pytest_configure(config):
    """Configure pytest settings"""
    import warnings
    warnings.filterwarnings("ignore", category=DeprecationWarning)
    warnings.filterwarnings("ignore", category=FutureWarning)
    warnings.filterwarnings("ignore", category=UserWarning) 