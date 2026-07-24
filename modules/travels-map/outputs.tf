output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.travels_map.domain_name
  description = ""
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.get_hiking_routes.api_endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.travels_map_front.id
}