# Create an IAM role for the Lambda function to execute Athena queries
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-athena-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"  # Allow Glue service to assume the role
        }
      },
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"  # Allow Athena service to assume the role
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-athena-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Athena Permissions
      {
        Action   = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetQueryResultsStream",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      # Glue Permissions for Lambda to read tables and interact with Glue catalog
      {
        Action   = [
          "glue:GetTable",
          "glue:GetTableVersion",
          "glue:GetTableVersions",
          "glue:GetDatabase",
          "glue:ListTables",
          "glue:GetTable"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:glue:eu-west-2:704964795421:catalog",
          "arn:aws:glue:eu-west-2:704964795421:database/my_glue_catalog_database",
          "arn:aws:glue:eu-west-2:704964795421:table/my_glue_catalog_database/*"
        ]
      },
      # S3 Permissions for Lambda to interact with Athena result bucket
      {
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:CreateBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::athena-query-results201",
          "arn:aws:s3:::athena-query-results201/*",
        ]
      },
      # CloudWatch Logs Permissions for Lambda to log
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      # Glue Crawler Permissions (to start and manage the crawler)
      {
        Action   = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics",
          "glue:UpdateCrawler",
          "glue:CreateTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchGetPartition",
          "glue:GetPartition",
          "glue:CreatePartition",
          "glue:DeletePartition",
          "glue:UpdatePartition",
          "glue:GetPartitions"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:glue:eu-west-2:704964795421:crawler/my-csv-glue-crawler",  # Update with your Glue Crawler ARN
          "arn:aws:glue:eu-west-2:704964795421:catalog",
          "arn:aws:glue:eu-west-2:704964795421:database/my_glue_catalog_database",
          "arn:aws:glue:eu-west-2:704964795421:table/my_glue_catalog_database/*"
        ]
      },
      # S3 Permissions for Glue Crawler to access your data (e.g., CSV files)
      {
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::my-csv-data101/*",  # S3 bucket for your data (CSV files)
          "arn:aws:s3:::my-csv-data101"
        ]
      },
       # Grant permissions to Glue service principal for UpdateTable and other required actions on Glue catalog tables
      {
        Action   = [
          "glue:UpdateTable"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:glue:eu-west-2:704964795421:catalog",
          "arn:aws:glue:eu-west-2:704964795421:database/my_glue_catalog_database",
          "arn:aws:glue:eu-west-2:704964795421:table/my_glue_catalog_database/my_csv_data101"
        ]
      }
    ]
  })
}

# Create the Lambda function for Athena queries
resource "aws_lambda_function" "athena_query_function" {
  function_name = "athena-query-to-s3"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"  # You can use the latest Python runtime

  # Specify the location of the Lambda function code, either as an S3 object or inline
  filename      = "lambda.zip"  # Local file path to your Lambda zip package

  environment {
    variables = {
      DATABASE_NAME    = "my_glue_catalog_database"   # Specify your Glue database name
      QUERY_STRING     = "SELECT * FROM my-csv-data101 LIMIT 10;"  # Modify query as needed
      OUTPUT_BUCKET    = "athena-query-results201"  # Specify your Athena results bucket
    }
  }
}

# Create CloudWatch Events rule to schedule Lambda function (e.g., every 1 hour)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name        = "athena-query-schedule"
  description = "Schedule Lambda function to run Athena query every 15 minutes"
  schedule_expression = "rate(15 minutes)"  # Customize the schedule as needed
}

# Lambda function trigger (CloudWatch event)
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "athena-query-target"
  arn       = aws_lambda_function.athena_query_function.arn
}

# Allow CloudWatch to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch_invocation" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_query_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
