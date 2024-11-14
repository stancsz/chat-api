# app.py
from flask import Flask
from mangum import Mangum

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "Hello, world!"

# Wrap the Flask app with Mangum for AWS Lambda
handler = Mangum(app)
