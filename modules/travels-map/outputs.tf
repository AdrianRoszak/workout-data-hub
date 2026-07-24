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

output "route53_nameservers" {
  value       = aws_route53_zone.travels_subdomain.name_servers
  description = "Route 53 nameservers for travels.weirdo.codes — add these as NS records in Vercel for the parent domain weirdo.codes"
}
