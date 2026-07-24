output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.travels_map.domain_name
  description = "CloudFront distribution domain name"
}

output "api_endpoint" {
  value       = aws_apigatewayv2_api.get_hiking_routes.api_endpoint
  description = "API Gateway HTTP endpoint for the travels map API"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.travels_map_front.id
  description = "S3 bucket hosting the Leaflet.js frontend"
}


output "site_url" {
  value       = "https://${var.subdomain}.${var.domain_name}"
  description = "URL of the travels map site (available after NS migration to AWS)"
}
