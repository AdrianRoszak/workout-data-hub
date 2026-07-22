resource "aws_dynamodb_table" "StravaActivities" {
  name = "StravaActivities"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "pk"
  range_key = "sk"
  
  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }
}

resource "aws_sns_topic" "StravaNotifications" {
  name = "StravaNotifications"
}
resource "aws_apigatewayv2_api" "strava_webhook" {
  name = "stravaWebhookHandler-API"
  description ="HTTP API Gateway v2 endpoint that receives Strava webhook callback (activity create/update/delete) and proxies them to the stravaWebhookHandler Lambda."
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "strava_webhook" {
  api_id = aws_apigatewayv2_api.strava_webhook.id
  route_key = "ANY /stravaWebhookHandler"
  target = "integrations/${aws_apigatewayv2_integration.strava_webhook.id}"
}

resource "aws_apigatewayv2_integration" "strava_webhook" {
  api_id = aws_apigatewayv2_api.strava_webhook.id
  integration_type = "AWS_PROXY"
  integration_uri = "arn:aws:lambda:eu-central-1:REDACTED_ACCOUNT_ID:function:stravaWebhookHandler"
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_stage" "strava_webhook" {
  api_id = aws_apigatewayv2_api.strava_webhook.id
  name = "default"
  auto_deploy = true
  description = "Production stage for the Strava webhook endpoint. Auto-deploys on route/integration changes."
}

resource "aws_lambda_permission" "strava_webhook" {
  statement_id = "lambda-0b89cde8-471a-49e3-ba04-bd2bebbf4d21"
  action = "lambda:InvokeFunction"
  function_name = "stravaWebhookHandler"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.strava_webhook.execution_arn}/*/*/stravaWebhookHandler"
}

resource "aws_lambda_function" "strava_webhook" {
  function_name = "stravaWebhookHandler"
  runtime = "python3.14"
  handler = "lambda_function.lambda_handler"
  role = "arn:aws:iam::REDACTED_ACCOUNT_ID:role/service-role/stravaWebhookHandler-role-4sow3cz9"
  filename = "${path.module}/src/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/src/lambda_function.zip")
  timeout = 3
  memory_size = 128
  architectures = ["x86_64"]

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.StravaNotifications.arn
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.StravaActivities.name
    }
  }
}