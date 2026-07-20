resource "aws_apigatewayv2_api" "strava_webhook" {
  name = "stravaWebhookHandler-API"
  description ="HTTP API Gateway v2 endpoint that receives Strava webhook callback (activity create/update/delete) and proxies them to the stravaWebhookHandler Lambda."
  protocol_type = "HTTP"
}