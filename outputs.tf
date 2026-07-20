output "website_url" {
  value       = module.website.website_url
  description = "The URL of the CloudFront distribution"
}

output "bucket_arn" {
  value       = module.website.bucket_arn
  description = "The ARN of the S3 bucket"
}

output "bucket_name" {
  value       = module.website.bucket_name
  description = "The name of the S3 bucket"
}
