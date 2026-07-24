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


output "cloudfront_cname_target" {
  value       = aws_cloudfront_distribution.travels_map.domain_name
  description = "Add a CNAME record in Vercel: travels → this value. After that, also add the ACM validation CNAME emailed to the domain owner."
}
