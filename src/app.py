import os
import json
import logging
import uuid

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Generate a unique request ID for tracing
    request_id = str(uuid.uuid4())
    logger.info(f"Request ID: {request_id} - Received event: {json.dumps(event)}")

    # Retrieve the verification token from environment variables
    verify_token = os.getenv('VERIFY_TOKEN')
    if not verify_token:
        logger.error(f"Request ID: {request_id} - VERIFY_TOKEN environment variable is not set.")
        return {
            'statusCode': 500,
            'body': 'Server configuration error.'
        }

    # Handle GET requests for webhook verification
    if event.get('requestContext', {}).get('http', {}).get('method') == 'GET':
        params = event.get('queryStringParameters', {})
        logger.info(f"Request ID: {request_id} - Received GET request with parameters: {params}")

        # Check if this is a Facebook verification request
        if params.get('hub.mode') == 'subscribe' and params.get('hub.verify_token') == verify_token:
            challenge = params.get('hub.challenge')
            if challenge:
                logger.info(f"Request ID: {request_id} - Webhook verified successfully.")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'text/plain'},
                    'body': challenge
                }
            else:
                logger.error(f"Request ID: {request_id} - hub.challenge parameter is missing.")
                return {
                    'statusCode': 400,
                    'body': 'Bad Request: Missing hub.challenge parameter.'
                }
        else:
            logger.error(f"Request ID: {request_id} - Webhook verification failed. Invalid verify_token or mode.")
            return {
                'statusCode': 403,
                'body': 'Forbidden: Verification failed.'
            }

    # Log unsupported methods
    else:
        logger.warning(f"Request ID: {request_id} - Received an unsupported HTTP method.")
        return {
            'statusCode': 405,
            'body': 'Method Not Allowed.'
        }
