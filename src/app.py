# src/app.py

def lambda_handler(event, context):
    """
    Simple AWS Lambda function that returns a greeting message.
    """
    return {
        'statusCode': 200,
        'body': 'Hello from AWS Lambda!'
    }