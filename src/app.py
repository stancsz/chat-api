# src/app.py
from flask import Flask
from mangum import Mangum

app = Flask(__name__)

@app.route("/", methods=["GET"])
def hello_world():
    return "Hello, world!"

@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE"])
def catch_all(path):
    return f"Hello, world! You requested path: /{path}"

# Wrap the Flask app with Mangum for AWS Lambda
handler = Mangum(app)