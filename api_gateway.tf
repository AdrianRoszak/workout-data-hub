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