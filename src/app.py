from flask import Flask
from mangum import Mangum

app = Flask(__name__)

@app.route("/", methods=["GET"])
def hello_world():
    return "Hello, World!"

# Wrap the Flask app with Mangum for AWS Lambda
handler = Mangum(app)