variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket to create"
  default     = "hello-world-weirdo-bucket-REDACTED_ACCOUNT_ID"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-central-1"
}
