resource "aws_lambda_permission" "strava_webhook" {
  statement_id = "lambda-0b89cde8-471a-49e3-ba04-bd2bebbf4d21"
  action = "lambda:InvokeFunction"
  function_name = "stravaWebhookHandler"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.strava_webhook.execution_arn}/*/*/stravaWebhookHandler"
}