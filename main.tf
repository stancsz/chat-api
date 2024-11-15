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

# 3. Create a Null Resource for Controlled Packaging
# Calculate the checksum of the source directory for better consistency
data "local_file" "app_hash" {
  filename = "${path.module}/src/app.py"
}

# Null resource to package the Lambda function only when the source code changes
resource "null_resource" "package_lambda" {
  provisioner "local-exec" {
    command = "python package_lambda.py"
  }

  # Trigger the null resource only when the source file changes
  triggers = {
    app_hash = data.local_file.app_hash.content
  }
}

# Lambda function configuration
resource "aws_lambda_function" "flask_lambda" {
  function_name = "my-flask-lambda"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "app.handler"
  runtime       = "python3.8"
  filename      = "${path.module}/app.zip"
  
  # Explicit source_code_hash to maintain consistency
  source_code_hash = filebase64sha256("${path.module}/app.zip")

  environment {
    variables = {
      # Add environment variables here if needed
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    null_resource.package_lambda
  ]
}

# 5. API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyFlaskAPI"
  description = "API for my Flask Lambda"
}

# 6. Proxy Resource (/{proxy+})
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

# 7. ANY Method for Proxy Resource (Set authorization to NONE for public access)
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# 8. Integration for Proxy Method
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}

# 9. ANY Method for Root Resource (Set authorization to NONE for public access)
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# 10. Integration for Root Method
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.root_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}

# 11. Deploy API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.proxy_integration,
    aws_api_gateway_integration.root_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# 12. Grant API Gateway Permission to Invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flask_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# 13. Output the API URL
output "api_url" {
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}"
  description = "Base URL of the deployed API"
}
