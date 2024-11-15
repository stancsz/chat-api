import json
import logging
from openai import OpenAI

# Configure logging
logging.basicConfig(level=logging.INFO)

def lambda_handler(event, context):
    try:
        prompt = event['prompt']
        api_key = ''

        if not api_key:
            raise ValueError("OpenAI API key not found.")
        client = OpenAI(api_key=api_key)
        messages = [{"role": "user", "content": prompt}]
        completion = client.chat.completions.create(model="gpt-4", messages=messages, max_tokens=250)
        response = completion.choices[0].message.content
        return {"statusCode": 200, "body": json.dumps({"response": response})}
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}