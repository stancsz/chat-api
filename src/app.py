from flask import Flask, request, jsonify
import os
import json
import logging
import uuid
from mangum import Mangum

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = Flask(__name__)

# Retrieve the verification token from environment variables
verify_token = os.getenv('VERIFY_TOKEN')
if not verify_token:
    logger.error("VERIFY_TOKEN environment variable is not set.")

@app.route('/webhook', methods=['GET', 'POST'])
def webhook():
    # Generate a unique request ID for tracing
    request_id = str(uuid.uuid4())
    logger.info(f"Request ID: {request_id} - Received event: {request.method}")

    # Handle GET requests for webhook verification
    if request.method == 'GET':
        params = request.args
        logger.info(f"Request ID: {request_id} - Received GET request with parameters: {params}")

        # Check if this is a test request with "test=true"
        if params.get('test') == 'true':
            logger.info(f"Request ID: {request_id} - Test request received, responding with 'Hello, world!'")
            return "Hello, world!", 200

        # Check if this is a Facebook verification request
        if params.get('hub.mode') == 'subscribe' and params.get('hub.verify_token') == verify_token:
            challenge = params.get('hub.challenge')
            if challenge:
                logger.info(f"Request ID: {request_id} - Webhook verified successfully.")
                return challenge, 200
            else:
                logger.error(f"Request ID: {request_id} - hub.challenge parameter is missing.")
                return 'Bad Request: Missing hub.challenge parameter.', 400
        else:
            logger.error(f"Request ID: {request_id} - Webhook verification failed. Invalid verify_token or mode.")
            return 'Forbidden: Verification failed.', 403

    # Handle unsupported methods
    logger.warning(f"Request ID: {request_id} - Received an unsupported HTTP method.")
    return 'Method Not Allowed.', 405

# Wrap the Flask app with Mangum for AWS Lambda
handler = Mangum(app)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
