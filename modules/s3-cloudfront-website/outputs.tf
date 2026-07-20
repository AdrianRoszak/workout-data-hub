output "website_url" {
  value       = "https://${aws_cloudfront_distribution.hello_world_distribution.domain_name}"
  description = "The URL of the CloudFront distribution"
}

output "bucket_arn" {
  value       = aws_s3_bucket.hello_world_bucket.arn
  description = "The ARN of the S3 bucket"
}

output "bucket_name" {
  value       = aws_s3_bucket.hello_world_bucket.bucket
  description = "The name of the S3 bucket"
}
