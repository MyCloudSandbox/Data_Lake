
resource "aws_s3_bucket" "athena_results_bucket" { # This is the bucket where Athena will store the query results
  bucket = "athena-query-results201"  
}

# Create an S3 bucket for the data source (CSV files)
resource "aws_s3_bucket" "csv_data" {
  bucket = "my-csv-data101"  # Specify your S3 bucket for CSV files
}

# Upload a CSV file to the CSV data bucket during terraform apply
resource "aws_s3_object" "csv_file" {
  bucket = aws_s3_bucket.csv_data.id
  key    = "sample.csv"  # S3 path to store the file
  source = "sample.csv"  # Local path to the CSV file
  acl    = "private"
}

# Create a CSV classifier
resource "aws_glue_classifier" "csv_classifier" {
  name = "csv_classifier"
  csv_classifier {
    delimiter = ","
    quote_symbol = "\""
    contains_header = "PRESENT"
  }
}

# Glue Crawler to discover data in CSV files
resource "aws_glue_crawler" "my_csv_crawler" {
  name          = "my-csv-glue-crawler"
  role          = aws_iam_role.lambda_execution_role.arn
  database_name = aws_glue_catalog_database.my_database.name  # Reference the Glue database name

  # Define the CSV data format and path to S3
    s3_target {
      path = "s3://my-csv-data101"  # Your S3 data location for CSV files
    }
  

  # Specify the CSV classifier
  classifiers = ["csv_classifier"]  # The Glue CSV classifier

  # Optional: Add a schedule if you want to run the crawler periodically
  schedule = "cron(*/30 * * * ? *)"  # Run every 30 minutes  # Example: Run at 12:00 UTC every day
}

# Glue Database for storing the schema
resource "aws_glue_catalog_database" "my_database" {
  name = "my_glue_catalog_database"  # Specify your Glue database name
}

# Glue Table (to define the CSV schema)
resource "aws_glue_catalog_table" "csv_table" {
  database_name = aws_glue_catalog_database.my_database.name
  name          = "my_csv_data101"  # Define your table name

  table_type = "EXTERNAL_TABLE"
  storage_descriptor {
    location = "s3://my-csv-data101/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    compressed    = false
    
    ser_de_info {
      name          = "csv"
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar" = ","
        "quoteChar"     = "\""
      }
    }
  }
}

# Outputs
output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results_bucket.bucket
}

output "csv_data_bucket" {
  value = aws_s3_bucket.csv_data.bucket
}
