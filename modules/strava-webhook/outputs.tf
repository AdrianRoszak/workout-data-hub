output "api_endpoint" {
  value       = aws_apigatewayv2_api.strava_webhook.api_endpoint
  description = "The invoke URL of the Strava webhook API Gateway"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.StravaActivities.name
  description = "DynamoDB table storing Strava activity events"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.StravaNotifications.arn
  description = "ARN of the SNS topic for Strava notifications"
}
