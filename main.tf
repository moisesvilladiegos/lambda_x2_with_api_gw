terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  access_key = ""
  secret_key = ""
}

data "archive_file" "lambda_javascript_n1" {
  type = "zip"
  source_file = "${path.module}/code/lambda_javascript_n1.js"
  output_path = "${path.module}/code/lambda_javascript_n1.zip"
}

data "archive_file" "lambda_python_n2" {
  type = "zip"
  source_file = "${path.module}/code/lambda_python_n2.py"
  output_path = "${path.module}/code/lambda_python_n2.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "serverless_lambda"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda_javascript_n1" {
  function_name = "WelcomeJavascript"
  filename = data.archive_file.lambda_javascript_n1.output_path
  source_code_hash = data.archive_file.lambda_javascript_n1.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "lambda_javascript_n1.handler"
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "lambda_python_n2" {
  function_name = "WelcomePython"
  filename = data.archive_file.lambda_python_n2.output_path
  source_code_hash = data.archive_file.lambda_python_n2.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "lambda_python_n2.lambda_handler"
  runtime = "python3.8"
}

resource "aws_apigatewayv2_api" "lambda" {
  name = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  name = "serverless_lambda_stage"
  api_id = aws_apigatewayv2_api.lambda.id
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_javascript_n1" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda_javascript_n1.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "lambda_python_n2" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda_python_n2.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_javascript_n1" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /is-js"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_javascript_n1.id}"
}

resource "aws_apigatewayv2_route" "lambda_python_n2" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /is-py"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_python_n2.id}"
}

resource "aws_lambda_permission" "api_gw_js" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_javascript_n1.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_py" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_python_n2.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}