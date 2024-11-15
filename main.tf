terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# 1. IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 2. Attach AWSLambdaBasicExecutionRole Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 3. Create an S3 bucket to store Lambda code
resource "aws_s3_bucket" "lambda_code_bucket" {
  # Provide a unique bucket name (change as needed)
  bucket = "my-flask-lambda-bucket"
  
  # We remove versioning and acl configuration here
}

# 4. Configure S3 bucket versioning
resource "aws_s3_bucket_versioning" "lambda_code_versioning" {
  bucket = aws_s3_bucket.lambda_code_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 5. Configure S3 bucket ACL (optional if you want a specific ACL)
resource "aws_s3_bucket_acl" "lambda_code_acl" {
  bucket = aws_s3_bucket.lambda_code_bucket.id
  acl    = "private"
}

# 6. Null Resource for Controlled Packaging of Lambda Function
resource "null_resource" "package_lambda" {
  provisioner "local-exec" {
    command = "python package_lambda.py"
  }

  triggers = {
    # Using the sha256 hash of the app.py content ensures
    # packaging only happens when the source code changes
    app_hash = filebase64sha256("${path.module}/src/app.py")
  }
}

# 7. Upload the packaged Lambda zip file to S3
resource "aws_s3_object" "lambda_zip" {
  depends_on  = [null_resource.package_lambda]  # Ensure packaging finishes first
  bucket      = aws_s3_bucket.lambda_code_bucket.id
  key         = "app.zip"
  source      = "${path.module}/app.zip"
  etag        = filemd5("${path.module}/app.zip")
}

# 8. Lambda function configuration using S3
resource "aws_lambda_function" "flask_lambda" {
  function_name = "my-flask-lambda"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  s3_bucket     = aws_s3_object.lambda_zip.bucket
  s3_key        = aws_s3_object.lambda_zip.key
  
  # Explicit source_code_hash to maintain consistency
  source_code_hash = filebase64sha256("${path.module}/app.zip")

  environment {
    variables = {
      # Add environment variables here if needed
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_s3_object.lambda_zip
  ]
}

# 9. API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyFlaskAPI"
  description = "API for my Flask Lambda"
}

# 10. Proxy Resource (/{proxy+})
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

# 11. ANY Method for Proxy Resource (Set authorization to NONE for public access)
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# 12. Integration for Proxy Method
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}

# 13. ANY Method for Root Resource (Set authorization to NONE for public access)
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# 14. Integration for Root Method
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.root_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}

# 15. Deploy API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.proxy_integration,
    aws_api_gateway_integration.root_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# 16. Grant API Gateway Permission to Invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flask_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# 17. Output the API URL
output "api_url" {
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
  description = "Base URL of the deployed API"
}
