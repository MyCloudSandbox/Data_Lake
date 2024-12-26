import json
import boto3
import time

athena_client = boto3.client('athena')
athena_results_bucket = 'athena-query-results201'  # Define your Athena results bucket
database_name = 'my_glue_catalog_database'  # Define your Glue database name
output_bucket = 'athena-query-results201'  # Define your output bucket
query_string = """
    SELECT * 
    FROM "my_glue_catalog_database"."my_csv_data101"
    LIMIT 10;
"""

def lambda_handler(event, context):
    # Start Athena query execution
    query_execution_id = start_athena_query(query_string)

    # Wait for query to complete and fetch the results
    query_results = get_athena_query_results(query_execution_id)
    
    # Process the results and write them to S3
    write_results_to_s3(query_results, output_bucket)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Athena query executed successfully!')
    }

def start_athena_query(query):
    """Start the Athena query and return the query execution ID"""
    response = athena_client.start_query_execution(
        QueryString=query,
        QueryExecutionContext={'Database': database_name},
        ResultConfiguration={
            'OutputLocation': f's3://{athena_results_bucket}/'
        }

    )
    return response['QueryExecutionId']

def get_athena_query_results(query_execution_id):
    """Wait for the Athena query to complete and fetch the results"""
    while True:
        response = athena_client.get_query_execution(
            QueryExecutionId=query_execution_id
        )
        state = response['QueryExecution']['Status']['State']
        if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(1)
    
    if state == 'SUCCEEDED':
        result_response = athena_client.get_query_results(QueryExecutionId=query_execution_id)
        print("Query succeeded, fetching results")
        return result_response['ResultSet']
    else:
        error_message = f"Query failed with state {state}"
        print(error_message)
        raise Exception(error_message)

def write_results_to_s3(query_results, output_bucket):
    """Write the query results to an S3 bucket"""
    s3_client = boto3.client('s3')
    s3_client.put_object(
        Bucket=output_bucket,
        Key='athena-query-results.json',
        Body=json.dumps(query_results)
    )